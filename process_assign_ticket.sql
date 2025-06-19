DECLARE
    l_ticket_id             Tickets.TicketID%TYPE       := TO_NUMBER(:PXX_TICKET_ID);
    l_assigned_to_user_id   Users.UserID%TYPE           := TO_NUMBER(:PXX_ASSIGN_TO_USER_ID);

    -- Variables for notification
    l_ticket_ref            Tickets.ReferenceNumber%TYPE;
    l_ticket_subject        Tickets.Subject%TYPE;
    l_message_text          AppNotifications.MessageText%TYPE;
    l_link_url              AppNotifications.LinkURL%TYPE;
    l_app_id                NUMBER;
    l_detail_page_id        NUMBER;

BEGIN
    -- Input Validation
    IF l_ticket_id IS NULL THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'Ticket ID is required to assign the ticket.',
            p_display_location => apex_error.c_inline_in_notification );
        RETURN; -- Stop processing
    END IF;

    -- Update Tickets table
    UPDATE Tickets
    SET
        AssignedToUserID = l_assigned_to_user_id,
        LastUpdateDate   = SYSDATE
    WHERE
        TicketID = l_ticket_id;

    -- Check if the update was successful
    IF SQL%ROWCOUNT > 0 THEN
        -- Attempt to create a notification, but don't let notification errors fail the main assignment
        BEGIN
            IF l_assigned_to_user_id IS NOT NULL THEN
                -- Fetch ticket details for the notification message
                BEGIN
                    SELECT ReferenceNumber, Subject
                    INTO l_ticket_ref, l_ticket_subject
                    FROM Tickets
                    WHERE TicketID = l_ticket_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- This should ideally not happen if the update above succeeded
                        apex_debug.error('Failed to fetch details for notification, ticket ID: ' || l_ticket_id);
                        l_ticket_ref := 'N/A'; -- Fallback
                        l_ticket_subject := 'N/A'; -- Fallback
                    WHEN OTHERS THEN
                        apex_debug.error('Error fetching ticket details for notification: ' || SQLERRM);
                        l_ticket_ref := 'Error';
                        l_ticket_subject := 'Error';
                END;

                l_app_id := V('APP_ID');
                l_detail_page_id := 10; -- Assuming Page 10 is the ticket detail page
                                        -- It's better to use an Application Item or a substitution string like &G_TICKET_DETAIL_PAGE_ID.

                -- Construct the URL to the ticket detail page
                l_link_url := APEX_PAGE.GET_URL(
                    p_application => l_app_id,
                    p_page        => l_detail_page_id,
                    p_items       => 'P' || l_detail_page_id || '_TICKET_ID', -- Assuming item name is P<PageID>_TICKET_ID
                    p_values      => l_ticket_id
                );

                l_message_text := 'تم تعيين البلاغ ' || l_ticket_ref || ' (الموضوع: ' || DBMS_LOB.SUBSTR(l_ticket_subject, 200) || ') لك.'; -- DBMS_LOB.SUBSTR for safety if subject is long

                INSERT INTO AppNotifications (
                    UserID,
                    NotificationType,
                    MessageText,
                    ReferenceID,
                    LinkURL,
                    IsRead,
                    CreationDate
                ) VALUES (
                    l_assigned_to_user_id,
                    'TICKET_ASSIGNED',
                    l_message_text,
                    l_ticket_id,
                    l_link_url,
                    0, -- 0 for Unread
                    SYSDATE
                );
            END IF; -- END IF l_assigned_to_user_id IS NOT NULL
        EXCEPTION
            WHEN OTHERS THEN
                -- Log the error for the notification creation but do not stop the whole process
                -- as the main ticket assignment was successful.
                apex_debug.error('Error creating notification for ticket assignment (TicketID: ' || l_ticket_id || '): ' || SQLERRM);
                -- Consider further logging to a custom error table if needed.
        END; -- End of notification block

    ELSE -- SQL%ROWCOUNT = 0 from ticket update
        APEX_ERROR.ADD_ERROR (
            p_message          => 'Ticket not found or no changes were made. Assignment may have failed.',
            p_display_location => apex_error.c_inline_in_notification );
        RAISE_APPLICATION_ERROR(-20002, 'Ticket with ID ' || l_ticket_id || ' not found for assignment, or no effective change.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'An error occurred while assigning the ticket: ' || SQLERRM,
            p_display_location => apex_error.c_inline_in_notification );
        RAISE;
END;
/
