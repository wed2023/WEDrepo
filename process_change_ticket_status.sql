DECLARE
    l_ticket_id         Tickets.TicketID%TYPE           := TO_NUMBER(:PXX_TICKET_ID);
    l_new_status_id     TicketStatuses.StatusID%TYPE    := TO_NUMBER(:PXX_NEW_TICKET_STATUS_ID);
    l_is_open_status    TicketStatuses.IsOpenStatus%TYPE;
BEGIN
    -- 3. Input Validation
    IF l_ticket_id IS NULL OR l_new_status_id IS NULL THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'Ticket ID and the new Status ID are required to change status.',
            p_display_location => apex_error.c_inline_in_notification );
        RETURN; -- Stop processing
    END IF;

    -- 4. Fetch IsOpenStatus property for the new status
    BEGIN
        SELECT IsOpenStatus
        INTO l_is_open_status
        FROM TicketStatuses
        WHERE StatusID = l_new_status_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'The selected new status is invalid or does not exist.',
                p_display_location => apex_error.c_inline_in_notification );
            RAISE_APPLICATION_ERROR(-20002, 'Invalid new status ID: ' || l_new_status_id);
        WHEN OTHERS THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Error fetching status details: ' || SQLERRM,
                p_display_location => apex_error.c_inline_in_notification );
            RAISE;
    END;

    -- 5. Update Tickets table
    UPDATE Tickets
    SET
        TicketStatusID = l_new_status_id,
        LastUpdateDate = SYSDATE,
        -- Set ClosedDate if the new status is a "closed" status (IsOpenStatus = 0)
        -- If it's an "open" status, set ClosedDate to NULL (in case it was previously closed)
        ClosedDate     = (CASE
                            WHEN l_is_open_status = 0 THEN NVL(ClosedDate, SYSDATE) -- If already closed, keep original closed date, else set to SYSDATE
                            ELSE NULL -- If reopening, clear the closed date
                          END)
    WHERE
        TicketID = l_ticket_id;

    -- Check if the update was successful
    IF SQL%ROWCOUNT = 0 THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'Ticket not found or status was not updated. Please verify the Ticket ID.',
            p_display_location => apex_error.c_inline_in_notification );
        RAISE_APPLICATION_ERROR(-20003, 'Ticket with ID ' || l_ticket_id || ' not found for status change.');
    END IF;

    -- 7. Success Message (configured in APEX process properties)
    -- Example: "Ticket status updated successfully."
    -- apex_application.g_print_success_message := 'Ticket status updated successfully.';

EXCEPTION
    WHEN OTHERS THEN
        -- 6. Basic Exception Handling
        APEX_ERROR.ADD_ERROR (
            p_message          => 'An error occurred while changing the ticket status: ' || SQLERRM,
            p_display_location => apex_error.c_inline_in_notification );
        RAISE;
END;
/
