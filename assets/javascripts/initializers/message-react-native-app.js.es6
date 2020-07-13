import { ajax } from "discourse/lib/ajax";
import { isAppWebview, postRNWebviewMessage } from "discourse/lib/utilities";
import User from "discourse/models/user";

export default {
  name: "message-react-native-app",
  after: "inject-objects",

  initialize(container) {
    const currentUser = container.lookup("current-user:main");

    if (isAppWebview() && currentUser) {
      postRNWebviewMessage("authenticated", 1);

      let appEvents = container.lookup("app-events:main");
      appEvents.on("page:changed", (data) => {
        let badgeCount =
          currentUser.unread_notifications +
          currentUser.unread_private_messages;

        postRNWebviewMessage("badgeCount", badgeCount);
      });
    }

    // called by webview if
    // 1. user is authenticated
    // 2. user has accepted push notifications
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
          // Note: might need to send endpoint_arn status to app
          // if (result.endpoint_arn && result.device_token) {
          postRNWebviewMessage("subscribe completed", result.endpoint_arn);
          // }
        });
      },
    });
  },
};
