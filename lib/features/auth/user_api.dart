import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class UserApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> getMe() async {
    final response = await _client.dio.get(AppConstants.getMe);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? firstName,
    String? lastName,
    String? email,
    String? altPhone,
    bool? seniorMode,
    // Address fields
    String? flatNo,
    String? building,
    String? street,
    String? city,
    String? state,
    String? country,
    String? pinCode,
  }) async {
    final data = <String, dynamic>{};
    if (fullName != null)   data['full_name']   = fullName;
    if (firstName != null)  data['first_name']  = firstName;
    if (lastName != null)   data['last_name']   = lastName;
    if (email != null)      data['email']        = email;
    if (altPhone != null)   data['alt_phone']    = altPhone;
    if (seniorMode != null) data['senior_mode']  = seniorMode;
    if (flatNo != null)     data['flat_no']      = flatNo;
    if (building != null)   data['building']     = building;
    if (street != null)     data['street']       = street;
    if (city != null)       data['city']         = city;
    if (state != null)      data['state']        = state;
    if (country != null)    data['country']      = country;
    if (pinCode != null)    data['pin_code']     = pinCode;

    // Derive full_name from first+last when updating profile details
    if (firstName != null && lastName != null && fullName == null) {
      data['full_name'] = '$firstName $lastName'.trim();
    }

    final response = await _client.dio.patch(AppConstants.updateMe, data: data);
    return response.data as Map<String, dynamic>;
  }
}
