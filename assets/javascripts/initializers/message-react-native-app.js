import { ajax } from "discourse/lib/ajax";
import { postRNWebviewMessage } from "discourse/lib/utilities";

export default {
  name: "message-react-native-app",
  after: "inject-objects",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    const caps = container.lookup("service:capabilities");

    if (caps.isAppWebview && currentUser) {
      postRNWebviewMessage("authenticated", 1);

      let appEvents = container.lookup("service:app-events");
      appEvents.on("page:changed", () => {
        let badgeCount =
          currentUser.unread_notifications +
          currentUser.unread_high_priority_notifications;

        postRNWebviewMessage("badgeCount", badgeCount);
      });
    }

    // called by webview
    window.SNS = {
      subscribeDeviceToken(token, platform, application_name) {
        ajax("/amazon-sns/subscribe.json", {
          type: "POST",
          data: {
            token,
            platform,
            application_name,
          },
        }).then((result) => {
          postRNWebviewMessage("subscribedToken", result);
        });
      },
      disableToken(token) {
        ajax("/amazon-sns/disable.json", {
          type: "POST",
          data: {
            token,
          },
        }).then((result) => {
          postRNWebviewMessage("disabledToken", result);
        });
      },
    };
  },
};
