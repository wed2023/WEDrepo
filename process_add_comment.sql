DECLARE
    l_ticket_id         Tickets.TicketID%TYPE := :PXX_TICKET_ID;
    l_user_id           Users.UserID%TYPE;
    l_comment_text      TicketComments.CommentText%TYPE := :PXX_NEW_COMMENT_TEXT;
    l_is_internal       TicketComments.IsInternal%TYPE := NVL(:PXX_IS_INTERNAL_COMMENT, 0); -- Default to 0 (Public) if checkbox is not checked or NULL
BEGIN
    -- 3. Get UserID for the current user
    BEGIN
        SELECT UserID
        INTO l_user_id
        FROM Users
        WHERE UserName = V('APP_USER'); -- Or APEX_APPLICATION.G_USER
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'User ' || V('APP_USER') || ' not found. Cannot add comment.',
                p_display_location => apex_error.c_inline_in_notification );
            RAISE; -- Stop processing
        WHEN OTHERS THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Error fetching current user ID: ' || SQLERRM,
                p_display_location => apex_error.c_inline_in_notification );
            RAISE; -- Stop processing
    END;

    -- 4. Validate that comment text is not empty
    IF l_comment_text IS NULL OR LENGTH(TRIM(l_comment_text)) = 0 THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'Comment text cannot be empty.',
            p_display_location => apex_error.c_inline_in_notification );
        -- No need to raise an error here if we want APEX to just show the message and stop.
        -- If we want to stop processing definitively and potentially rollback (though not much to rollback yet):
        -- RAISE_APPLICATION_ERROR(-20001, 'Comment text cannot be empty.');
        RETURN; -- Stop processing if validation fails
    END IF;

    -- Validate Ticket ID
    IF l_ticket_id IS NULL THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'Ticket ID is missing. Cannot add comment.',
            p_display_location => apex_error.c_inline_in_notification );
        RETURN; -- Stop processing
    END IF;


    -- 5. Insert data into TicketComments table
    INSERT INTO TicketComments (
        TicketID,
        UserID,
        CommentDate,
        CommentText,
        IsInternal
    ) VALUES (
        l_ticket_id,
        l_user_id,
        SYSDATE,
        l_comment_text,
        l_is_internal
    );

    -- 6. Update LastUpdateDate in Tickets table
    UPDATE Tickets
    SET LastUpdateDate = SYSDATE
    WHERE TicketID = l_ticket_id;

    -- Optional: Add a success message (can also be configured in APEX process settings)
    -- apex_application.g_print_success_message := 'Comment added successfully.';

EXCEPTION
    WHEN OTHERS THEN
        -- 7. Basic Exception Handling
        APEX_ERROR.ADD_ERROR (
            p_message          => 'An error occurred while adding the comment: ' || SQLERRM,
            p_display_location => apex_error.c_inline_in_notification );
        -- Re-raise the exception if you want APEX to fully handle it after your message
        RAISE;
END;
/
