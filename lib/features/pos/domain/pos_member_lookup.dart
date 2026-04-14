import 'package:phongchai_pos/data/mock/mock_data_store.dart';
import 'package:phongchai_pos/data/models/member_lookup_hit.dart';

export 'package:phongchai_pos/data/models/member_lookup_hit.dart';

/// ค้นหาสมาชิกจากเบอร์ — ข้อมูลจาก `assets/mock/members_by_phone.json`
MemberLookupHit? memberLookupByPhone(String raw) {
  return MockDataStore.instance.memberLookupByPhone(raw);
}

String? memberNameForPhone(String raw) => memberLookupByPhone(raw)?.name;
