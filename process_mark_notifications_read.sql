DECLARE
    l_current_user_id   NUMBER;
BEGIN
    -- Attempt to get the numeric UserID.
    -- In a real APEX application, :APP_USER might be the username (VARCHAR2).
    -- If :APP_CURRENT_USER_ID is guaranteed to be the numeric ID, this direct assignment is fine.
    -- Otherwise, a lookup would be needed:
    -- SELECT UserID INTO l_current_user_id FROM Users WHERE UserName = :APP_USER;
    -- For this task, we assume :APP_CURRENT_USER_ID is correctly populated as a number.

    l_current_user_id := :APP_CURRENT_USER_ID;

    IF l_current_user_id IS NULL THEN
        -- This case should ideally not happen if the page/process is protected
        -- and :APP_CURRENT_USER_ID is expected to be set.
        apex_debug.warn('Attempted to mark notifications as read, but UserID is NULL.');
        RETURN; -- Exit if no user ID is available
    END IF;

    UPDATE AppNotifications
    SET
        IsRead = 1,
        ReadDate = SYSDATE
    WHERE
        UserID = l_current_user_id
        AND IsRead = 0
        AND ReadDate IS NULL; -- Only update those that haven't been marked as read before

    -- No explicit success message is usually needed for this type of background process,
    -- but you can log the number of rows updated if desired.
    -- apex_debug.info('Notifications marked as read for UserID ' || l_current_user_id || ': ' || SQL%ROWCOUNT || ' rows updated.');

EXCEPTION
    WHEN OTHERS THEN
        apex_debug.error('Error in process_mark_notifications_read for UserID ' || l_current_user_id || ': ' || SQLERRM);
        -- Optionally, re-raise the exception if it should stop further processing or be visible
        -- RAISE;
        -- Or handle silently as this is often a background task.
END;
/
