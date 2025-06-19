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
