class Assistant::Builtin < Assistant::Base
  include Assistant::Provided
  include Assistant::Configurable

  attr_reader :instructions

  class << self
    def for_chat(chat)
      config = config_for(chat)
      new(chat, instructions: config[:instructions], functions: config[:functions])
    end
  end

  def initialize(chat, instructions: nil, functions: [])
    super(chat)
    @instructions = instructions
    @functions = functions
  end

  def respond_to(message)
    assistant_message = AssistantMessage.new(
      chat: chat,
      content: "",
      ai_model: message.ai_model
    )

    llm_provider = get_model_provider(message.ai_model)
    unless llm_provider
      raise StandardError, build_no_provider_error_message(message.ai_model)
    end

    responder = Assistant::Responder.new(
      message: message,
      instructions: instructions,
      function_tool_caller: function_tool_caller,
      llm: llm_provider
    )

    latest_response_id = chat.latest_assistant_response_id
    replace_content_on_next_text = false

    responder.on(:output_text) do |text|
      next if text.nil? || text.empty?

      Rails.logger.debug("[Assistant] output_text delta: #{text.truncate(200).inspect}")

      # When the previous response had function calls, some providers (e.g., vLLM)
      # may have streamed function call arguments as text. Replace that content
      # with the actual follow-up response text instead of appending.
      if replace_content_on_next_text
        Rails.logger.info("[Assistant] Replacing content (was: #{assistant_message.content.truncate(100).inspect})")
        replace_content_on_next_text = false
        assistant_message.content = text
        assistant_message.save!(validate: false)
      elsif !assistant_message.persisted?
        stop_thinking
        Chat.transaction do
          assistant_message.append_text!(text)
          chat.update_latest_response!(latest_response_id)
        end
      else
        assistant_message.append_text!(text)
      end
    end

    responder.on(:response) do |data|
      update_thinking("Analyzing your data...")
      if data[:function_tool_calls].present?
        tool_names = data[:function_tool_calls].map(&:function_name).join(", ")
        Rails.logger.info("[Assistant] Response with function calls: #{tool_names}")
        # Ensure assistant_message is persisted before setting tool_calls association.
        unless assistant_message.persisted?
          assistant_message.save!(validate: false)
        end
        assistant_message.tool_calls = data[:function_tool_calls]
        latest_response_id = data[:id]
        # Flag to replace (not append) content on the next output_text event,
        # discarding any function call argument text streamed by the provider.
        replace_content_on_next_text = true
      else
        Rails.logger.info("[Assistant] Response complete (id: #{data[:id]})")
        chat.update_latest_response!(data[:id])
      end
    end

    responder.respond(previous_response_id: latest_response_id)

    Rails.logger.info("[Assistant] Final message content: #{assistant_message.content.truncate(500).inspect}")
  rescue => e
    stop_thinking
    chat.add_error(e)
  end

  private

    attr_reader :functions

    def function_tool_caller
      @function_tool_caller ||= Assistant::FunctionToolCaller.new(
        functions.map { |fn| fn.new(chat.user) }
      )
    end

    def build_no_provider_error_message(requested_model)
      available_providers = registry.providers
      if available_providers.empty?
        "No LLM provider configured that supports model '#{requested_model}'. " \
          "Please configure an LLM provider (e.g., OpenAI) in settings."
      else
        provider_details = available_providers.map do |provider|
          "  - #{provider.provider_name}: #{provider.supported_models_description}"
        end.join("\n")
        "No LLM provider configured that supports model '#{requested_model}'.\n\n" \
          "Available providers:\n#{provider_details}\n\n" \
          "Please either:\n" \
          "  1. Use a supported model from the list above, or\n" \
          "  2. Configure a provider that supports '#{requested_model}' in settings."
      end
    end
end
