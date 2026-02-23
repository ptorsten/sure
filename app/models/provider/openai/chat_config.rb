class Provider::Openai::ChatConfig
  def initialize(functions: [], function_results: [], include_function_calls: false)
    @functions = functions
    @function_results = function_results
    @include_function_calls = include_function_calls
  end

  def tools
    functions.map do |fn|
      {
        type: "function",
        name: fn[:name],
        description: fn[:description],
        parameters: fn[:params_schema],
        strict: fn[:strict]
      }
    end
  end

  def build_input(prompt)
    items = []

    function_results.each do |fn_result|
      # When previous_response_id is not used (e.g., custom providers), the server
      # has no memory of the function_call from the first response. Include it in
      # the input so the server can match function_call_output to its call.
      if include_function_calls
        items << {
          type: "function_call",
          id: fn_result[:id] || "fc_#{fn_result[:call_id]}",
          call_id: fn_result[:call_id],
          name: fn_result[:name],
          arguments: fn_result[:arguments].is_a?(String) ? fn_result[:arguments] : fn_result[:arguments].to_json
        }
      end

      # Handle nil explicitly to avoid serializing to "null"
      output = fn_result[:output]
      serialized_output = if output.nil?
        ""
      elsif output.is_a?(String)
        output
      else
        output.to_json
      end

      items << {
        type: "function_call_output",
        call_id: fn_result[:call_id],
        output: serialized_output
      }
    end

    [
      { role: "user", content: prompt },
      *items
    ]
  end

  private
    attr_reader :functions, :function_results, :include_function_calls
end
