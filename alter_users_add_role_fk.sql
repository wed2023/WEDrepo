ALTER TABLE Users
ADD CONSTRAINT FK_Users_Role
FOREIGN KEY (RoleID)
REFERENCES Roles(RoleID);

-- ملاحظة: سلوك الحذف ON DELETE RESTRICT هو السلوك الافتراضي في Oracle
-- إذا لم يتم تحديد ON DELETE SET NULL أو ON DELETE CASCADE.
-- لذلك، لا يلزم كتابة "ON DELETE RESTRICT" صراحة، ولكن تم تضمين هذه الملاحظة للتوضيح.
-- إذا كان الدور مرتبطًا بأي مستخدمين، فلن يتم السماح بحذف الدور.
