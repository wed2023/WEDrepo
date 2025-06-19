DECLARE
    l_user_id         Users.UserID%TYPE;
    l_username        Users.UserName%TYPE         := :PXX_USERNAME;
    l_full_name       Users.FullName%TYPE         := :PXX_FULL_NAME;
    l_email           Users.Email%TYPE            := :PXX_EMAIL;
    l_password        VARCHAR2(4000)              := :PXX_PASSWORD; -- Raw password from page item
    l_confirm_password VARCHAR2(4000)             := :PXX_CONFIRM_PASSWORD; -- Raw confirm password from page item
    l_role_id         Users.RoleID%TYPE           := TO_NUMBER(:PXX_ROLE_ID);
    l_department_id   Users.DepartmentID%TYPE     := TO_NUMBER(:PXX_DEPARTMENT_ID);
    l_is_active       Users.IsActive%TYPE         := NVL(TO_NUMBER(:PXX_IS_ACTIVE), 0); -- Default to 0 if NULL or not checked

    l_password_hash   Users.PasswordHash%TYPE;
BEGIN
    -- 2. Get UserID (can be NULL for new user)
    -- Using TO_NUMBER directly on :PXX_USER_ID might raise an error if it's null and "Submit when Enter pressed" is No for the item.
    -- A safer way if the item might not be submitted when null:
    IF :PXX_USER_ID IS NOT NULL THEN
        l_user_id := TO_NUMBER(:PXX_USER_ID);
    ELSE
        l_user_id := NULL;
    END IF;

    -- 3. Password Hashing Logic
    IF l_password IS NOT NULL THEN
        -- Optional: Add check for password confirmation match
        IF l_password != l_confirm_password THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Passwords do not match.',
                p_display_location => apex_error.c_inline_in_notification );
            RETURN; -- Stop processing
        END IF;

        -- Use APEX_UTIL.PREPARE_PASSWORD_HASH for secure hashing
        -- This function handles salt generation and hashing according to current APEX security standards.
        l_password_hash := APEX_UTIL.PREPARE_PASSWORD_HASH(p_password => l_password);

        -- For older APEX versions, or if specific hashing (e.g. with username as salt) is needed:
        -- l_password_hash := APEX_UTIL.GET_HASH(p_string => apex_util.prepare_password(p_password => l_password, p_username => l_username), p_checksum_type => 'SHA256');
        -- Note: MD5 is not recommended. SHA256 or stronger should be used.
    END IF;

    -- 4. Create or Update Logic
    IF l_user_id IS NULL THEN
        -- Create new user
        -- Optional: Check if password hash is null (meaning password was not provided)
        IF l_password_hash IS NULL THEN
            APEX_ERROR.ADD_ERROR (
                p_message          => 'Password is required for new user.',
                p_display_location => apex_error.c_inline_in_notification );
            RETURN; -- Stop processing
        END IF;

        -- Validate required fields for new user (can also be done with APEX validations)
        IF l_username IS NULL OR l_full_name IS NULL OR l_email IS NULL THEN
             APEX_ERROR.ADD_ERROR (
                p_message          => 'Username, Full Name, and Email are required for new user.',
                p_display_location => apex_error.c_inline_in_notification );
            RETURN; -- Stop processing
        END IF;


        INSERT INTO Users (
            UserName,
            FullName,
            Email,
            PasswordHash,
            RoleID,
            DepartmentID,
            IsActive,
            CreatedDate,
            LastLoginDate -- Typically NULL on creation
        ) VALUES (
            l_username,
            l_full_name,
            l_email,
            l_password_hash,
            l_role_id,
            l_department_id,
            l_is_active,
            SYSDATE,
            NULL
        );
        -- Set success message for creation
        apex_application.g_print_success_message := 'User ' || l_username || ' created successfully.';

    ELSE
        -- Update existing user
        UPDATE Users
        SET
            UserName        = l_username,
            FullName        = l_full_name,
            Email           = l_email,
            PasswordHash    = NVL(l_password_hash, PasswordHash), -- Update password only if a new one is provided
            RoleID          = l_role_id,
            DepartmentID    = l_department_id,
            IsActive        = l_is_active
            -- LastLoginDate is usually updated by a login trigger/process
        WHERE
            UserID = l_user_id;

        -- Set success message for update
        apex_application.g_print_success_message := 'User ' || l_username || ' updated successfully.';
    END IF;

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        -- Handle unique constraint violations (e.g., UserName or Email already exists)
        -- Note: Oracle error for unique constraint is ORA-00001. DUP_VAL_ON_INDEX is a predefined exception.
        -- It's better to check which constraint was violated if possible, or provide a general message.
        -- For example, by checking SQLERRM for constraint name.
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
        -- Re-raise if you want APEX to fully handle it after your message
        RAISE;
END;
/
