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
        ELSE 'غير محدد' -- Or handle NULL if IsActive can be NULL, though it's defined as NOT NULL
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
