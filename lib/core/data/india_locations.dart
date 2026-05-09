/// Map of Indian state names → list of major cities.
/// Add more states/cities as needed.
const Map<String, List<String>> indiaLocations = {
  'Andhra Pradesh': [
    'Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool',
    'Rajahmundry', 'Tirupati', 'Kakinada', 'Anantapur', 'Eluru',
  ],
  'Arunachal Pradesh': [
    'Itanagar', 'Naharlagun', 'Pasighat', 'Tezpur',
  ],
  'Assam': [
    'Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Nagaon',
    'Tinsukia', 'Tezpur', 'Bongaigaon', 'Dhubri',
  ],
  'Bihar': [
    'Patna', 'Gaya', 'Muzaffarpur', 'Bhagalpur', 'Darbhanga',
    'Purnia', 'Arrah', 'Begusarai', 'Katihar', 'Munger',
  ],
  'Chhattisgarh': [
    'Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Durg',
    'Rajnandgaon', 'Jagdalpur', 'Ambikapur',
  ],
  'Goa': [
    'Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda',
  ],
  'Gujarat': [
    'Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar',
    'Jamnagar', 'Junagadh', 'Gandhinagar', 'Anand', 'Navsari',
    'Morbi', 'Mehsana', 'Bharuch', 'Porbandar', 'Surendranagar',
  ],
  'Haryana': [
    'Faridabad', 'Gurgaon', 'Panipat', 'Ambala', 'Yamunanagar',
    'Rohtak', 'Hisar', 'Karnal', 'Sonipat', 'Panchkula',
  ],
  'Himachal Pradesh': [
    'Shimla', 'Manali', 'Dharamshala', 'Solan', 'Mandi',
    'Palampur', 'Baddi', 'Kullu',
  ],
  'Jharkhand': [
    'Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Deoghar',
    'Phusro', 'Hazaribagh', 'Giridih', 'Dumka', 'Ramgarh',
  ],
  'Karnataka': [
    'Bengaluru', 'Mysuru', 'Hubballi', 'Mangaluru', 'Belagavi',
    'Kalaburagi', 'Ballari', 'Davanagere', 'Shivamogga', 'Tumakuru',
    'Vijayapura', 'Bidar', 'Raichur', 'Hassan', 'Dharwad',
  ],
  'Kerala': [
    'Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kollam',
    'Palakkad', 'Alappuzha', 'Malappuram', 'Kannur', 'Kasaragod',
  ],
  'Madhya Pradesh': [
    'Bhopal', 'Indore', 'Jabalpur', 'Gwalior', 'Ujjain',
    'Sagar', 'Dewas', 'Satna', 'Ratlam', 'Rewa',
    'Murwara', 'Singrauli', 'Burhanpur', 'Khandwa', 'Bhind',
  ],
  'Maharashtra': [
    'Mumbai', 'Pune', 'Nagpur', 'Thane', 'Nashik',
    'Aurangabad', 'Solapur', 'Navi Mumbai', 'Kolhapur', 'Amravati',
    'Malegaon', 'Sangli', 'Jalgaon', 'Akola', 'Latur',
    'Dhule', 'Nanded', 'Chandrapur', 'Parbhani', 'Panvel',
  ],
  'Manipur': [
    'Imphal', 'Thoubal', 'Kakching', 'Ukhrul', 'Churachandpur',
  ],
  'Meghalaya': [
    'Shillong', 'Tura', 'Jowai', 'Nongstoin',
  ],
  'Mizoram': [
    'Aizawl', 'Lunglei', 'Champhai', 'Serchhip',
  ],
  'Nagaland': [
    'Kohima', 'Dimapur', 'Mokokchung', 'Wokha', 'Tuensang',
  ],
  'Odisha': [
    'Bhubaneswar', 'Cuttack', 'Rourkela', 'Brahmapur', 'Sambalpur',
    'Puri', 'Balasore', 'Bhadrak', 'Baripada', 'Angul',
  ],
  'Punjab': [
    'Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda',
    'Hoshiarpur', 'Mohali', 'Gurdaspur', 'Pathankot', 'Moga',
  ],
  'Rajasthan': [
    'Jaipur', 'Jodhpur', 'Kota', 'Bikaner', 'Ajmer',
    'Udaipur', 'Bhilwara', 'Alwar', 'Bharatpur', 'Sikar',
    'Pali', 'Sri Ganganagar', 'Beawar', 'Merta City',
  ],
  'Sikkim': [
    'Gangtok', 'Namchi', 'Mangan', 'Gyalshing',
  ],
  'Tamil Nadu': [
    'Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem',
    'Tirunelveli', 'Vellore', 'Erode', 'Tirupur', 'Thoothukudi',
    'Dindigul', 'Thanjavur', 'Ranipet', 'Sivakasi', 'Karur',
    'Udhagamandalam', 'Hosur', 'Nagercoil', 'Kanchipuram',
  ],
  'Telangana': [
    'Hyderabad', 'Warangal', 'Nizamabad', 'Khammam', 'Karimnagar',
    'Ramagundam', 'Mahbubnagar', 'Nalgonda', 'Adilabad', 'Suryapet',
  ],
  'Tripura': [
    'Agartala', 'Dharmanagar', 'Udaipur', 'Kailasahar', 'Belonia',
  ],
  'Uttar Pradesh': [
    'Lucknow', 'Kanpur', 'Ghaziabad', 'Agra', 'Varanasi',
    'Meerut', 'Prayagraj', 'Bareilly', 'Aligarh', 'Moradabad',
    'Saharanpur', 'Gorakhpur', 'Firozabad', 'Noida', 'Jhansi',
    'Muzaffarnagar', 'Mathura', 'Rampur', 'Shahjahanpur', 'Farrukhabad',
  ],
  'Uttarakhand': [
    'Dehradun', 'Haridwar', 'Roorkee', 'Haldwani', 'Rudrapur',
    'Kashipur', 'Rishikesh', 'Kotdwara', 'Nainital',
  ],
  'West Bengal': [
    'Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri',
    'Bardhaman', 'Malda', 'Baharampur', 'Habra', 'Kharagpur',
    'Shantipur', 'Dankuni', 'Dhulian', 'Ranaghat', 'Haldia',
  ],
  // Union Territories
  'Andaman & Nicobar': ['Port Blair'],
  'Chandigarh': ['Chandigarh'],
  'Dadra & Nagar Haveli': ['Silvassa'],
  'Daman & Diu': ['Daman', 'Diu'],
  'Delhi': ['New Delhi', 'Dwarka', 'Rohini', 'Pitampura', 'Karol Bagh', 'Lajpat Nagar', 'Saket', 'Janakpuri'],
  'Jammu & Kashmir': ['Srinagar', 'Jammu', 'Anantnag', 'Baramulla', 'Udhampur'],
  'Ladakh': ['Leh', 'Kargil'],
  'Lakshadweep': ['Kavaratti'],
  'Puducherry': ['Puducherry', 'Karaikal', 'Mahé', 'Yanam'],
};

/// Sorted list of all state/UT names for the dropdown.
final List<String> indiaStates = indiaLocations.keys.toList()..sort();
