import firebase_admin

from firebase_admin import (
    credentials,
    messaging
)

try:

    firebase_admin.get_app()

except ValueError:

    cred = credentials.Certificate(
        "firebase_key.json"
    )

    firebase_admin.initialize_app(
        cred
    )


def send_notification(
    token,
    title,
    body
):

    try:

        message = messaging.Message(

            notification=
            messaging.Notification(
                title=title,
                body=body
            ),

            token=token
        )

        response = messaging.send(
            message
        )

        print(
            "FCM SENT:",
            response
        )

    except Exception as e:

        print(
            "FCM ERROR:",
            str(e)
        )