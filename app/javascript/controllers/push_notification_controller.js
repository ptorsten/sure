import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="push-notification"
export default class extends Controller {
  static values = {
    configUrl: { type: String, default: "/api/v1/push/config" },
    subscribeUrl: { type: String, default: "/api/v1/push_subscriptions" },
  };

  async connect() {
    if (!this.#isSupported()) return;

    this.config = await this.#fetchConfig();
    if (!this.config?.enabled) return;

    await this.#registerServiceWorker();
  }

  async subscribe() {
    if (!this.config?.enabled) {
      console.warn("Push notifications not configured");
      return;
    }

    try {
      const permission = await Notification.requestPermission();
      if (permission !== "granted") return;

      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.#urlBase64ToUint8Array(
          this.config.vapid_public_key
        ),
      });

      await this.#saveSubscription(subscription);
    } catch (error) {
      console.error("Failed to subscribe to push:", error);
    }
  }

  async unsubscribe() {
    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();

      if (subscription) {
        await subscription.unsubscribe();
        // Optionally notify server
      }
    } catch (error) {
      console.error("Failed to unsubscribe:", error);
    }
  }

  // Private methods

  #isSupported() {
    return "serviceWorker" in navigator && "PushManager" in window;
  }

  async #fetchConfig() {
    try {
      const response = await fetch(this.configUrlValue);
      return await response.json();
    } catch {
      return null;
    }
  }

  async #registerServiceWorker() {
    try {
      await navigator.serviceWorker.register("/service-worker");
    } catch (error) {
      console.error("Service worker registration failed:", error);
    }
  }

  async #saveSubscription(subscription) {
    const token = this.#getAuthToken();
    if (!token) return;

    const response = await fetch(this.subscribeUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ subscription: subscription.toJSON() }),
    });

    if (!response.ok) {
      throw new Error("Failed to save subscription");
    }
  }

  #getAuthToken() {
    // Get token from meta tag or localStorage
    const meta = document.querySelector('meta[name="api-token"]');
    return meta?.content || localStorage.getItem("api_token");
  }

  #urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding)
      .replace(/-/g, "+")
      .replace(/_/g, "/");
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }
}
