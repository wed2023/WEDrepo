-- استعلام لتقرير أداء المستخدمين المبدئي
-- ملاحظة: Closed_By_User_Tickets في هذا الاستعلام تعني البلاغات المغلقة
-- والتي لا تزال معينة حاليًا لهذا المستخدم. هذا لا يعني بالضرورة أن هذا المستخدم
-- هو من قام بإجراء الإغلاق. تتبع من قام بالإغلاق يتطلب عادةً تتبع تاريخ تغييرات الحالة
-- أو وجود عمود مخصص مثل "ClosedByUserID".
SELECT
    U.FullName AS User_FullName,
    U.UserName AS User_UserName,
    COUNT(CASE WHEN TS.IsOpenStatus = 1 THEN T.TicketID ELSE NULL END) AS Assigned_Open_Tickets,
    COUNT(CASE WHEN TS.IsOpenStatus = 0 THEN T.TicketID ELSE NULL END) AS Assigned_Closed_Tickets -- Renamed for clarity based on definition
FROM
    Users U
LEFT JOIN
    Tickets T ON U.UserID = T.AssignedToUserID -- Join on tickets currently assigned to this user
LEFT JOIN
    TicketStatuses TS ON T.TicketStatusID = TS.StatusID
GROUP BY
    U.UserID, U.FullName, U.UserName
ORDER BY
    User_FullName ASC;
