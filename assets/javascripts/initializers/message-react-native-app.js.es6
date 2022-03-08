import { ajax } from "discourse/lib/ajax";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import User from "discourse/models/user";

export default {
  name: "message-react-native-app",
  after: "inject-objects",

  initialize(container) {
    const currentUser = container.lookup("current-user:main");
    const caps = container.lookup("capabilities:main");

    if (caps.isAppWebview && currentUser) {
      postRNWebviewMessage("authenticated", 1);

      let appEvents = container.lookup("app-events:main");
      appEvents.on("page:changed", (data) => {
        let badgeCount =
          currentUser.unread_notifications +
          currentUser.unread_private_messages;

        postRNWebviewMessage("badgeCount", badgeCount);
      });
    }

    // TODO: remove this legacy call in December 2020 (app should use window.SNS calls below)
    User.reopenClass({
      subscribeDeviceToken(token, platform, application_name) {
        ajax("/amazon-sns/subscribe.json", {
          type: "POST",
          data: {
            token: token,
            platform: platform,
            application_name: application_name,
          },
        }).then((result) => {
          postRNWebviewMessage("subscribe completed", result.endpoint_arn);
        });
      },
    });

    // called by webview
    window.SNS = {
      subscribeDeviceToken(token, platform, application_name) {
        ajax("/amazon-sns/subscribe.json", {
          type: "POST",
          data: {
            token: token,
            platform: platform,
            application_name: application_name,
          },
        }).then((result) => {
          postRNWebviewMessage("subscribedToken", result);
        });
      },
      disableToken(token) {
        ajax("/amazon-sns/disable.json", {
          type: "POST",
          data: {
            token: token,
          },
        }).then((result) => {
          postRNWebviewMessage("disabledToken", result);
        });
      },
    };
  },
};
