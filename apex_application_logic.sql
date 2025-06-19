-- ==== PROCESS FOR Create New Ticket ====
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
-- ==============================================

-- ==== QUERY FOR Ticket List Interactive Report ====
SELECT
    t.TicketID,
    t.ReferenceNumber,
    t.Subject,
    ts.StatusName,
    p.PriorityName,
    d.DepartmentName,
    u_assigned.FullName AS AssignedToUserFullName,
    u_submitted.FullName AS SubmittedByUserFullName,
    t.SubmissionDate,
    t.LastUpdateDate,
    t.CallerName
FROM
    Tickets t
LEFT JOIN
    TicketStatuses ts ON t.TicketStatusID = ts.StatusID
LEFT JOIN
    Priorities p ON t.PriorityID = p.PriorityID
LEFT JOIN
    Departments d ON t.DepartmentID = d.DepartmentID
LEFT JOIN
    Users u_assigned ON t.AssignedToUserID = u_assigned.UserID
LEFT JOIN
    Users u_submitted ON t.SubmittedByUserID = u_submitted.UserID
ORDER BY
    t.LastUpdateDate DESC, t.SubmissionDate DESC;
-- ==============================================

-- ==== QUERY FOR Ticket Details Region ====
SELECT
    T.TicketID,
    T.ReferenceNumber,
    T.Subject,
    T.Description,
    TS.StatusName,
    TP.PriorityName,
    TT.TypeName,
    D.DepartmentName,
    T.CallerName,
    T.CallerContactInfo,
    U_Submitted.FullName AS SubmittedByUserFullName,
    T.SubmissionDate,
    U_Assigned.FullName AS AssignedToUserFullName,
    T.LastUpdateDate,
    T.ClosedDate
FROM
    Tickets T
LEFT JOIN
    TicketStatuses TS ON T.TicketStatusID = TS.StatusID
LEFT JOIN
    Priorities TP ON T.PriorityID = TP.PriorityID
LEFT JOIN
    TicketTypes TT ON T.TicketTypeID = TT.TypeID
LEFT JOIN
    Departments D ON T.DepartmentID = D.DepartmentID
LEFT JOIN
    Users U_Submitted ON T.SubmittedByUserID = U_Submitted.UserID
LEFT JOIN
    Users U_Assigned ON T.AssignedToUserID = U_Assigned.UserID
WHERE
    T.TicketID = :PXX_TICKET_ID;
-- ==============================================

-- ==== QUERY FOR Ticket Attachments List ====
SELECT
    TA.AttachmentID,
    TA.FileName,
    TA.FileSize,
    TA.UploadDate,
    U.FullName AS UploadedByUserFullName
FROM
    TicketAttachments TA
LEFT JOIN
    Users U ON TA.UploadedByUserID = U.UserID
WHERE
    TA.TicketID = :PXX_TICKET_ID
ORDER BY
    TA.UploadDate DESC;
-- ==============================================

-- ==== QUERY FOR Ticket Comments List ====
SELECT
    TC.CommentID, -- It's good practice to select the ID for potential actions/links
    TC.CommentText,
    TC.CommentDate,
    U.FullName AS CommentByUserFullName,
    TC.IsInternal -- This can be used to conditionally display comments or style them
FROM
    TicketComments TC
LEFT JOIN
    Users U ON TC.UserID = U.UserID
WHERE
    TC.TicketID = :PXX_TICKET_ID
ORDER BY
    TC.CommentDate DESC;
-- ==============================================

-- ==== PROCESS FOR Add New Comment ====
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

EXCEPTION
    WHEN OTHERS THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'An error occurred while adding the comment: ' || SQLERRM,
            p_display_location => apex_error.c_inline_in_notification );
        RAISE;
END;
/
-- ==============================================

-- ==== QUERY FOR User List Interactive Report ====
SELECT
    U.UserID,
    U.UserName,
    U.FullName,
    U.Email,
    R.RoleName,
    D.DepartmentName,
    CASE U.IsActive
        WHEN 1 THEN 'نشط'
        WHEN 0 THEN 'غير نشط'
        ELSE 'غير محدد'
    END AS ActivityStatus,
    U.CreatedDate,
    U.LastLoginDate
FROM
    Users U
LEFT JOIN
    Roles R ON U.RoleID = R.RoleID
LEFT JOIN
    Departments D ON U.DepartmentID = D.DepartmentID
ORDER BY
    U.CreatedDate DESC, U.UserName ASC;
-- ==============================================

-- ==== PROCESS FOR Save User Data (Create/Update) ====
DECLARE
    l_user_id         Users.UserID%TYPE;
    l_username        Users.UserName%TYPE         := :PXX_USERNAME;
    l_full_name       Users.FullName%TYPE         := :PXX_FULL_NAME;
    l_email           Users.Email%TYPE            := :PXX_EMAIL;
    l_password        VARCHAR2(4000)              := :PXX_PASSWORD;
    l_confirm_password VARCHAR2(4000)             := :PXX_CONFIRM_PASSWORD;
    l_role_id         Users.RoleID%TYPE           := TO_NUMBER(:PXX_ROLE_ID);
    l_department_id   Users.DepartmentID%TYPE     := TO_NUMBER(:PXX_DEPARTMENT_ID);
    l_is_active       Users.IsActive%TYPE         := NVL(TO_NUMBER(:PXX_IS_ACTIVE), 0);

    l_password_hash   Users.PasswordHash%TYPE;
BEGIN
    IF :PXX_USER_ID IS NOT NULL THEN
        l_user_id := TO_NUMBER(:PXX_USER_ID);
    ELSE
        l_user_id := NULL;
    END IF;

    IF l_password IS NOT NULL THEN
        IF l_password != l_confirm_password THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Passwords do not match.',
                p_display_location => apex_error.c_inline_in_notification );
            RETURN;
        END IF;
        l_password_hash := APEX_UTIL.PREPARE_PASSWORD_HASH(p_password => l_password);
    END IF;

    IF l_user_id IS NULL THEN
        IF l_password_hash IS NULL THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Password is required for new user.',
                p_display_location => apex_error.c_inline_in_notification );
            RETURN;
        END IF;

        IF l_username IS NULL OR l_full_name IS NULL OR l_email IS NULL THEN
             APEX_ERROR.ADD_ERROR (
                p_message          => 'Username, Full Name, and Email are required for new user.',
                p_display_location => apex_error.c_inline_in_notification );
            RETURN;
        END IF;

        INSERT INTO Users (
            UserName, FullName, Email, PasswordHash, RoleID, DepartmentID, IsActive, CreatedDate, LastLoginDate
        ) VALUES (
            l_username, l_full_name, l_email, l_password_hash, l_role_id, l_department_id, l_is_active, SYSDATE, NULL
        );
        apex_application.g_print_success_message := 'User ' || l_username || ' created successfully.';
    ELSE
        UPDATE Users
        SET
            UserName        = l_username,
            FullName        = l_full_name,
            Email           = l_email,
            PasswordHash    = NVL(l_password_hash, PasswordHash),
            RoleID          = l_role_id,
            DepartmentID    = l_department_id,
            IsActive        = l_is_active
        WHERE UserID = l_user_id;
        apex_application.g_print_success_message := 'User ' || l_username || ' updated successfully.';
    END IF;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        IF INSTR(SQLERRM, 'USERS_USERNAME_UK') > 0 THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Username ''' || l_username || ''' already exists. Please choose a different username.',
                p_display_location => apex_error.c_inline_with_field,
                p_page_item_name   => 'PXX_USERNAME');
        ELSIF INSTR(SQLERRM, 'USERS_EMAIL_UK') > 0 THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Email ''' || l_email || ''' is already registered. Please use a different email.',
                p_display_location => apex_error.c_inline_with_field,
                p_page_item_name   => 'PXX_EMAIL');
        ELSE
            APEX_ERROR.ADD_ERROR (
                p_message          => 'A unique constraint violation occurred: ' || SQLERRM,
                p_display_location => apex_error.c_inline_in_notification );
        END IF;
    WHEN OTHERS THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'An error occurred while saving user data: ' || SQLERRM,
            p_display_location => apex_error.c_inline_in_notification );
        RAISE;
END;
/
-- ==============================================

-- ==== PROCESS FOR Assign Ticket to User ====
DECLARE
    l_ticket_id             Tickets.TicketID%TYPE       := TO_NUMBER(:PXX_TICKET_ID);
    l_assigned_to_user_id   Users.UserID%TYPE           := TO_NUMBER(:PXX_ASSIGN_TO_USER_ID);

    l_ticket_ref            Tickets.ReferenceNumber%TYPE;
    l_ticket_subject        Tickets.Subject%TYPE;
    l_message_text          AppNotifications.MessageText%TYPE;
    l_link_url              AppNotifications.LinkURL%TYPE;
    l_app_id                NUMBER;
    l_detail_page_id        NUMBER;
BEGIN
    IF l_ticket_id IS NULL THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'Ticket ID is required to assign the ticket.',
            p_display_location => apex_error.c_inline_in_notification );
        RETURN;
    END IF;

    UPDATE Tickets
    SET AssignedToUserID = l_assigned_to_user_id, LastUpdateDate   = SYSDATE
    WHERE TicketID = l_ticket_id;

    IF SQL%ROWCOUNT > 0 THEN
        BEGIN
            IF l_assigned_to_user_id IS NOT NULL THEN
                BEGIN
                    SELECT ReferenceNumber, Subject INTO l_ticket_ref, l_ticket_subject
                    FROM Tickets WHERE TicketID = l_ticket_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        apex_debug.error('Failed to fetch details for notification, ticket ID: ' || l_ticket_id);
                        l_ticket_ref := 'N/A';
                        l_ticket_subject := 'N/A';
                    WHEN OTHERS THEN
                        apex_debug.error('Error fetching ticket details for notification: ' || SQLERRM);
                        l_ticket_ref := 'Error';
                        l_ticket_subject := 'Error';
                END;

                l_app_id := V('APP_ID');
                l_detail_page_id := 10;

                l_link_url := APEX_PAGE.GET_URL(
                    p_application => l_app_id,
                    p_page        => l_detail_page_id,
                    p_items       => 'P' || l_detail_page_id || '_TICKET_ID',
                    p_values      => l_ticket_id
                );
                l_message_text := 'تم تعيين البلاغ ' || l_ticket_ref || ' (الموضوع: ' || DBMS_LOB.SUBSTR(l_ticket_subject, 200) || ') لك.';
                INSERT INTO AppNotifications (
                    UserID, NotificationType, MessageText, ReferenceID, LinkURL, IsRead, CreationDate
                ) VALUES (
                    l_assigned_to_user_id, 'TICKET_ASSIGNED', l_message_text, l_ticket_id, l_link_url, 0, SYSDATE
                );
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                apex_debug.error('Error creating notification for ticket assignment (TicketID: ' || l_ticket_id || '): ' || SQLERRM);
        END;
    ELSE
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
-- ==============================================

-- ==== PROCESS FOR Change Ticket Status ====
DECLARE
    l_ticket_id         Tickets.TicketID%TYPE           := TO_NUMBER(:PXX_TICKET_ID);
    l_new_status_id     TicketStatuses.StatusID%TYPE    := TO_NUMBER(:PXX_NEW_TICKET_STATUS_ID);
    l_is_open_status    TicketStatuses.IsOpenStatus%TYPE;
BEGIN
    IF l_ticket_id IS NULL OR l_new_status_id IS NULL THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'Ticket ID and the new Status ID are required to change status.',
            p_display_location => apex_error.c_inline_in_notification );
        RETURN;
    END IF;

    BEGIN
        SELECT IsOpenStatus INTO l_is_open_status
        FROM TicketStatuses WHERE StatusID = l_new_status_id;
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

    UPDATE Tickets
    SET
        TicketStatusID = l_new_status_id,
        LastUpdateDate = SYSDATE,
        ClosedDate     = (CASE
                            WHEN l_is_open_status = 0 THEN NVL(ClosedDate, SYSDATE)
                            ELSE NULL
                          END)
    WHERE TicketID = l_ticket_id;

    IF SQL%ROWCOUNT = 0 THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'Ticket not found or status was not updated. Please verify the Ticket ID.',
            p_display_location => apex_error.c_inline_in_notification );
        RAISE_APPLICATION_ERROR(-20003, 'Ticket with ID ' || l_ticket_id || ' not found for status change.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        APEX_ERROR.ADD_ERROR (
            p_message          => 'An error occurred while changing the ticket status: ' || SQLERRM,
            p_display_location => apex_error.c_inline_in_notification );
        RAISE;
END;
/
-- ==============================================

-- ==== QUERY FOR Unread Notifications Count ====
SELECT
    COUNT(*) AS UnreadCount
FROM
    AppNotifications
WHERE
    UserID = :APP_CURRENT_USER_ID AND IsRead = 0;
-- ==============================================

-- ==== QUERY FOR User Notifications List ====
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
-- ==============================================

-- ==== PROCESS FOR Mark Notifications as Read ====
DECLARE
    l_current_user_id   NUMBER;
BEGIN
    l_current_user_id := :APP_CURRENT_USER_ID;

    IF l_current_user_id IS NULL THEN
        apex_debug.warn('Attempted to mark notifications as read, but UserID is NULL.');
        RETURN;
    END IF;

    UPDATE AppNotifications
    SET IsRead = 1, ReadDate = SYSDATE
    WHERE UserID = l_current_user_id AND IsRead = 0 AND ReadDate IS NULL;
EXCEPTION
    WHEN OTHERS THEN
        apex_debug.error('Error in process_mark_notifications_read for UserID ' || l_current_user_id || ': ' || SQLERRM);
END;
/
-- ==============================================

-- ==== QUERY FOR Tickets by Status Summary (Report/Chart) ====
SELECT
    TS.StatusName AS Status_Name,
    COUNT(T.TicketID) AS Number_Of_Tickets
FROM
    TicketStatuses TS
LEFT JOIN
    Tickets T ON TS.StatusID = T.TicketStatusID
GROUP BY
    TS.StatusID, TS.StatusName, TS.StatusOrder
ORDER BY
    TS.StatusOrder ASC, TS.StatusName ASC;
-- ==============================================

-- ==== QUERY FOR Tickets by Department Summary (Report/Chart) ====
SELECT
    D.DepartmentName AS Department_Name,
    COUNT(CASE WHEN TS.IsOpenStatus = 1 THEN T.TicketID ELSE NULL END) AS Open_Tickets,
    COUNT(CASE WHEN TS.IsOpenStatus = 0 THEN T.TicketID ELSE NULL END) AS Closed_Tickets,
    COUNT(T.TicketID) AS Total_Tickets
FROM
    Departments D
LEFT JOIN
    Tickets T ON D.DepartmentID = T.DepartmentID
LEFT JOIN
    TicketStatuses TS ON T.TicketStatusID = TS.StatusID
GROUP BY
    D.DepartmentID, D.DepartmentName
ORDER BY
    D.DepartmentName ASC;
-- ==============================================

-- ==== QUERY FOR User Performance Summary (Initial Report/Chart) ====
-- ملاحظة: Closed_By_User_Tickets في هذا الاستعلام تعني البلاغات المغلقة
-- والتي لا تزال معينة حاليًا لهذا المستخدم. هذا لا يعني بالضرورة أن هذا المستخدم
-- هو من قام بإجراء الإغلاق. تتبع من قام بالإغلاق يتطلب عادةً تتبع تاريخ تغييرات الحالة
-- أو وجود عمود مخصص مثل "ClosedByUserID".
SELECT
    U.FullName AS User_FullName,
    U.UserName AS User_UserName,
    COUNT(CASE WHEN TS.IsOpenStatus = 1 THEN T.TicketID ELSE NULL END) AS Assigned_Open_Tickets,
    COUNT(CASE WHEN TS.IsOpenStatus = 0 THEN T.TicketID ELSE NULL END) AS Assigned_Closed_Tickets
FROM
    Users U
LEFT JOIN
    Tickets T ON U.UserID = T.AssignedToUserID
LEFT JOIN
    TicketStatuses TS ON T.TicketStatusID = TS.StatusID
GROUP BY
    U.UserID, U.FullName, U.UserName
ORDER BY
    User_FullName ASC;
-- ==============================================

-- ==== QUERY FOR Average Ticket Resolution Time (Report/Chart) ====
WITH TicketDurations AS (
    SELECT
        T.TicketID,
        T.TicketTypeID,
        T.PriorityID,
        T.DepartmentID,
        (T.ClosedDate - T.SubmissionDate) AS Duration_In_Days
    FROM
        Tickets T
    WHERE
        T.ClosedDate IS NOT NULL
        AND T.SubmissionDate IS NOT NULL
        AND T.ClosedDate >= T.SubmissionDate
        AND T.TicketStatusID IN (SELECT StatusID FROM TicketStatuses WHERE IsOpenStatus = 0)
)
SELECT
    'Overall Average' AS Grouping_Type,
    NULL AS Grouping_Value_ID,
    NULL AS Grouping_Value_Name,
    ROUND(AVG(TD.Duration_In_Days), 2) AS Avg_Resolution_Time_Days,
    COUNT(TD.TicketID) AS Total_Closed_Tickets_Calculated
FROM
    TicketDurations TD
UNION ALL
SELECT
    'By Ticket Type' AS Grouping_Type,
    TD.TicketTypeID AS Grouping_Value_ID,
    TT.TypeName AS Grouping_Value_Name,
    ROUND(AVG(TD.Duration_In_Days), 2) AS Avg_Resolution_Time_Days,
    COUNT(TD.TicketID) AS Total_Closed_Tickets_Calculated
FROM
    TicketDurations TD
JOIN
    TicketTypes TT ON TD.TicketTypeID = TT.TypeID
GROUP BY
    TD.TicketTypeID, TT.TypeName
UNION ALL
SELECT
    'By Priority' AS Grouping_Type,
    TD.PriorityID AS Grouping_Value_ID,
    P.PriorityName AS Grouping_Value_Name,
    ROUND(AVG(TD.Duration_In_Days), 2) AS Avg_Resolution_Time_Days,
    COUNT(TD.TicketID) AS Total_Closed_Tickets_Calculated
FROM
    TicketDurations TD
JOIN
    Priorities P ON TD.PriorityID = P.PriorityID
GROUP BY
    TD.PriorityID, P.PriorityName
UNION ALL
SELECT
    'By Department' AS Grouping_Type,
    TD.DepartmentID AS Grouping_Value_ID,
    D.DepartmentName AS Grouping_Value_Name,
    ROUND(AVG(TD.Duration_In_Days), 2) AS Avg_Resolution_Time_Days,
    COUNT(TD.TicketID) AS Total_Closed_Tickets_Calculated
FROM
    TicketDurations TD
JOIN
    Departments D ON TD.DepartmentID = D.DepartmentID
WHERE
    TD.DepartmentID IS NOT NULL
GROUP BY
    TD.DepartmentID, D.DepartmentName
ORDER BY
    Grouping_Type ASC, Grouping_Value_Name ASC;
-- ==============================================
