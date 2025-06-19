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
