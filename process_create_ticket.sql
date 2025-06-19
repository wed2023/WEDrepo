DECLARE
    -- Variables for page items
    l_caller_name           Tickets.CallerName%TYPE := :PXX_CALLER_NAME;
    l_caller_contact_info   Tickets.CallerContactInfo%TYPE := :PXX_CALLER_CONTACT_INFO;
    l_ticket_type_id        Tickets.TicketTypeID%TYPE := :PXX_TICKET_TYPE_ID;
    l_priority_id           Tickets.PriorityID%TYPE := :PXX_PRIORITY_ID;
    l_department_id         Tickets.DepartmentID%TYPE := :PXX_DEPARTMENT_ID; -- Can be NULL
    l_subject               Tickets.Subject%TYPE := :PXX_SUBJECT;
    l_description           Tickets.Description%TYPE := :PXX_DESCRIPTION;
    l_attachments_item_value VARCHAR2(32767) := :PXX_ATTACHMENTS; -- Value of the file browse page item

    -- System generated values
    l_submitted_by_user_id  Tickets.SubmittedByUserID%TYPE;
    l_default_status_id     Tickets.TicketStatusID%TYPE;
    l_reference_number      Tickets.ReferenceNumber%TYPE;
    l_new_ticket_id         Tickets.TicketID%TYPE;

BEGIN
    -- 3. Get System Values
    -- Get UserID from APP_USER (assuming APP_USER stores the username)
    BEGIN
        SELECT UserID
        INTO l_submitted_by_user_id
        FROM Users
        WHERE UserName = V('APP_USER'); -- Or APEX_APPLICATION.G_USER
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'User ' || V('APP_USER') || ' not found in Users table. Cannot create ticket.',
                p_display_location => apex_error.c_inline_in_notification );
            RAISE;
        WHEN OTHERS THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Error fetching submitting user ID: ' || SQLERRM,
                p_display_location => apex_error.c_inline_in_notification );
            RAISE;
    END;

    -- Get default status ID for 'New' status
    BEGIN
        SELECT StatusID
        INTO l_default_status_id
        FROM TicketStatuses
        WHERE StatusName = 'New'; -- Ensure this status exists
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Default ticket status ''New'' not found in TicketStatuses table. Cannot create ticket.',
                p_display_location => apex_error.c_inline_in_notification );
            RAISE;
        WHEN OTHERS THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Error fetching default status ID: ' || SQLERRM,
                p_display_location => apex_error.c_inline_in_notification );
            RAISE;
    END;

    -- 4. Generate ReferenceNumber (ensure sequence Tickets_RefNum_Seq exists)
    -- Example: CREATE SEQUENCE Tickets_RefNum_Seq START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
    l_reference_number := 'TKT-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-' || LPAD(Tickets_RefNum_Seq.NEXTVAL, 5, '0');

    -- 5. Insert data into Tickets table
    INSERT INTO Tickets (
        ReferenceNumber,
        SubmissionDate,
        SubmittedByUserID,
        CallerName,
        CallerContactInfo,
        TicketTypeID,
        TicketStatusID,
        PriorityID,
        DepartmentID,
        Subject,
        Description,
        LastUpdateDate
    ) VALUES (
        l_reference_number,
        SYSDATE,
        l_submitted_by_user_id,
        l_caller_name,
        l_caller_contact_info,
        l_ticket_type_id,
        l_default_status_id,
        l_priority_id,
        l_department_id,
        l_subject,
        l_description,
        SYSDATE
    ) RETURNING TicketID INTO l_new_ticket_id;

    -- 6. Process Attachments
    IF l_attachments_item_value IS NOT NULL THEN
        FOR rec IN (SELECT filename, mime_type, blob_content
                    FROM apex_application_files
                    WHERE name IN (SELECT regexp_substr(l_attachments_item_value,'[^:]+', 1, level)
                                   FROM dual
                                   CONNECT BY regexp_substr(l_attachments_item_value, '[^:]+', 1, level) IS NOT NULL)
                   )
        LOOP
            INSERT INTO TicketAttachments (
                TicketID,
                UploadedByUserID,
                FileName,
                FileMIMEType,
                FileContent,
                UploadDate,
                FileSize
            ) VALUES (
                l_new_ticket_id,
                l_submitted_by_user_id,
                rec.filename,
                rec.mime_type,
                rec.blob_content,
                SYSDATE,
                DBMS_LOB.GETLENGTH(rec.blob_content)
            );
        END LOOP;

        -- After processing, clean up the files from APEX temporary storage
        DELETE FROM apex_application_files
        WHERE name IN (SELECT regexp_substr(l_attachments_item_value,'[^:]+', 1, level)
                       FROM dual
                       CONNECT BY regexp_substr(l_attachments_item_value, '[^:]+', 1, level) IS NOT NULL);
    END IF;


    -- Set page items to be used in success message if needed
    :PXX_LAST_TICKET_ID := l_new_ticket_id;
    :PXX_LAST_TICKET_REF := l_reference_number;

EXCEPTION
    WHEN OTHERS THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'An error occurred while creating the ticket: ' || SQLERRM,
            p_display_location => apex_error.c_inline_in_notification );
        RAISE;
END;
/
