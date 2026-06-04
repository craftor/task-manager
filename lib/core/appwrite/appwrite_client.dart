import 'package:appwrite/appwrite.dart';

/// Global Appwrite client for the task_manager project.
///
/// Project details are intentionally hardcoded as requested by the
/// initial Appwrite SDK setup step of the Supabase → Appwrite migration.
/// Any future environment-specific configuration should replace these
/// values with the appropriate secure-credentials flow.
final Client client = Client()
    .setProject('6a20e0b10013cae75d20')
    .setEndpoint('http://o.21up.cn:6080/v1');
