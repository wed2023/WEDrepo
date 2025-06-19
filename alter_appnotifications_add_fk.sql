ALTER TABLE AppNotifications
ADD CONSTRAINT FK_AppNotifications_User
FOREIGN KEY (UserID)
REFERENCES Users(UserID)
ON DELETE CASCADE;

-- ملاحظة: ON DELETE CASCADE يعني أنه عند حذف مستخدم من جدول Users،
-- سيتم حذف جميع الإشعارات المرتبطة بهذا المستخدم تلقائيًا من جدول AppNotifications.
-- يجب استخدام هذا السلوك بحذر والتأكد من أنه يتوافق مع متطلبات العمل.
