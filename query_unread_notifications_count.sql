SELECT
    COUNT(*) AS UnreadCount
FROM
    AppNotifications
WHERE
    UserID = :APP_CURRENT_USER_ID AND IsRead = 0;
