SELECT
    NotificationID,
    NotificationType,
    MessageText,
    LinkURL,
    CreationDate,
    IsRead,
    ReadDate,
    ReferenceID
FROM
    AppNotifications
WHERE
    UserID = :APP_CURRENT_USER_ID
ORDER BY
    CreationDate DESC;
