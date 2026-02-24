//
//  CountryCode.swift
//  CopyLab
//

import Foundation

struct CountryCode: Identifiable, Equatable, Hashable {
    let id: String          // ISO 2-letter code
    let name: String
    let dialCode: String    // e.g. "+1"
    let formatPattern: String // '#' = digit slot, other chars are literals

    var flag: String {
        id.uppercased().unicodeScalars
            .compactMap { Unicode.Scalar(127397 + $0.value) }
            .map(String.init)
            .joined()
    }

    /// Max digits accepted for this country (count of '#' in pattern)
    var maxDigits: Int {
        formatPattern.filter { $0 == "#" }.count
    }

    /// Format raw digit string using the country's pattern
    func format(_ digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        var result = ""
        var digitIndex = digits.startIndex
        for char in formatPattern {
            guard digitIndex < digits.endIndex else { break }
            if char == "#" {
                result.append(digits[digitIndex])
                digitIndex = digits.index(after: digitIndex)
            } else {
                result.append(char)
            }
        }
        return result
    }
}

extension CountryCode {
    static let defaultCountry = all.first { $0.id == "US" }!

    static let all: [CountryCode] = [
        // ── Top picks ──────────────────────────────────────────────────────────
        CountryCode(id: "US", name: "United States",            dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "GB", name: "United Kingdom",           dialCode: "+44",  formatPattern: "#### ### ####"),
        // ── A ──────────────────────────────────────────────────────────────────
        CountryCode(id: "AF", name: "Afghanistan",              dialCode: "+93",  formatPattern: "## ### ####"),
        CountryCode(id: "AL", name: "Albania",                  dialCode: "+355", formatPattern: "## ### ####"),
        CountryCode(id: "DZ", name: "Algeria",                  dialCode: "+213", formatPattern: "### ## ## ##"),
        CountryCode(id: "AD", name: "Andorra",                  dialCode: "+376", formatPattern: "### ###"),
        CountryCode(id: "AO", name: "Angola",                   dialCode: "+244", formatPattern: "### ### ###"),
        CountryCode(id: "AG", name: "Antigua and Barbuda",      dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "AR", name: "Argentina",                dialCode: "+54",  formatPattern: "## ####-####"),
        CountryCode(id: "AM", name: "Armenia",                  dialCode: "+374", formatPattern: "## ######"),
        CountryCode(id: "AU", name: "Australia",                dialCode: "+61",  formatPattern: "#### ### ###"),
        CountryCode(id: "AT", name: "Austria",                  dialCode: "+43",  formatPattern: "### ######"),
        CountryCode(id: "AZ", name: "Azerbaijan",               dialCode: "+994", formatPattern: "## ### ## ##"),
        // ── B ──────────────────────────────────────────────────────────────────
        CountryCode(id: "BS", name: "Bahamas",                  dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "BH", name: "Bahrain",                  dialCode: "+973", formatPattern: "#### ####"),
        CountryCode(id: "BD", name: "Bangladesh",               dialCode: "+880", formatPattern: "#### ######"),
        CountryCode(id: "BB", name: "Barbados",                 dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "BY", name: "Belarus",                  dialCode: "+375", formatPattern: "## ###-##-##"),
        CountryCode(id: "BE", name: "Belgium",                  dialCode: "+32",  formatPattern: "### ## ## ##"),
        CountryCode(id: "BZ", name: "Belize",                   dialCode: "+501", formatPattern: "### ####"),
        CountryCode(id: "BJ", name: "Benin",                    dialCode: "+229", formatPattern: "## ## ## ##"),
        CountryCode(id: "BT", name: "Bhutan",                   dialCode: "+975", formatPattern: "## ### ###"),
        CountryCode(id: "BO", name: "Bolivia",                  dialCode: "+591", formatPattern: "# ### ####"),
        CountryCode(id: "BA", name: "Bosnia and Herzegovina",   dialCode: "+387", formatPattern: "## ### ###"),
        CountryCode(id: "BW", name: "Botswana",                 dialCode: "+267", formatPattern: "## ### ###"),
        CountryCode(id: "BR", name: "Brazil",                   dialCode: "+55",  formatPattern: "(##) #####-####"),
        CountryCode(id: "BN", name: "Brunei",                   dialCode: "+673", formatPattern: "### ####"),
        CountryCode(id: "BG", name: "Bulgaria",                 dialCode: "+359", formatPattern: "## ### ####"),
        CountryCode(id: "BF", name: "Burkina Faso",             dialCode: "+226", formatPattern: "## ## ## ##"),
        CountryCode(id: "BI", name: "Burundi",                  dialCode: "+257", formatPattern: "## ## ## ##"),
        // ── C ──────────────────────────────────────────────────────────────────
        CountryCode(id: "CV", name: "Cabo Verde",               dialCode: "+238", formatPattern: "### ## ##"),
        CountryCode(id: "KH", name: "Cambodia",                 dialCode: "+855", formatPattern: "## ### ###"),
        CountryCode(id: "CM", name: "Cameroon",                 dialCode: "+237", formatPattern: "#### ####"),
        CountryCode(id: "CA", name: "Canada",                   dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "CF", name: "Central African Republic", dialCode: "+236", formatPattern: "## ## ## ##"),
        CountryCode(id: "TD", name: "Chad",                     dialCode: "+235", formatPattern: "## ## ## ##"),
        CountryCode(id: "CL", name: "Chile",                    dialCode: "+56",  formatPattern: "# #### ####"),
        CountryCode(id: "CN", name: "China",                    dialCode: "+86",  formatPattern: "### #### ####"),
        CountryCode(id: "CO", name: "Colombia",                 dialCode: "+57",  formatPattern: "### ### ####"),
        CountryCode(id: "KM", name: "Comoros",                  dialCode: "+269", formatPattern: "### ## ##"),
        CountryCode(id: "CG", name: "Congo",                    dialCode: "+242", formatPattern: "## ### ####"),
        CountryCode(id: "CD", name: "Congo (DRC)",              dialCode: "+243", formatPattern: "## ### ####"),
        CountryCode(id: "CR", name: "Costa Rica",               dialCode: "+506", formatPattern: "#### ####"),
        CountryCode(id: "HR", name: "Croatia",                  dialCode: "+385", formatPattern: "## ### ####"),
        CountryCode(id: "CU", name: "Cuba",                     dialCode: "+53",  formatPattern: "### ## ####"),
        CountryCode(id: "CY", name: "Cyprus",                   dialCode: "+357", formatPattern: "## ######"),
        CountryCode(id: "CZ", name: "Czech Republic",           dialCode: "+420", formatPattern: "### ### ###"),
        // ── D ──────────────────────────────────────────────────────────────────
        CountryCode(id: "DK", name: "Denmark",                  dialCode: "+45",  formatPattern: "## ## ## ##"),
        CountryCode(id: "DJ", name: "Djibouti",                 dialCode: "+253", formatPattern: "## ## ## ##"),
        CountryCode(id: "DM", name: "Dominica",                 dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "DO", name: "Dominican Republic",       dialCode: "+1",   formatPattern: "(###) ###-####"),
        // ── E ──────────────────────────────────────────────────────────────────
        CountryCode(id: "EC", name: "Ecuador",                  dialCode: "+593", formatPattern: "## ### ####"),
        CountryCode(id: "EG", name: "Egypt",                    dialCode: "+20",  formatPattern: "### #### ####"),
        CountryCode(id: "SV", name: "El Salvador",              dialCode: "+503", formatPattern: "#### ####"),
        CountryCode(id: "GQ", name: "Equatorial Guinea",        dialCode: "+240", formatPattern: "### ######"),
        CountryCode(id: "ER", name: "Eritrea",                  dialCode: "+291", formatPattern: "# ### ###"),
        CountryCode(id: "EE", name: "Estonia",                  dialCode: "+372", formatPattern: "#### ####"),
        CountryCode(id: "SZ", name: "Eswatini",                 dialCode: "+268", formatPattern: "## ### ###"),
        CountryCode(id: "ET", name: "Ethiopia",                 dialCode: "+251", formatPattern: "## ### ####"),
        // ── F ──────────────────────────────────────────────────────────────────
        CountryCode(id: "FJ", name: "Fiji",                     dialCode: "+679", formatPattern: "### ####"),
        CountryCode(id: "FI", name: "Finland",                  dialCode: "+358", formatPattern: "## ### ## ##"),
        CountryCode(id: "FR", name: "France",                   dialCode: "+33",  formatPattern: "# ## ## ## ##"),
        // ── G ──────────────────────────────────────────────────────────────────
        CountryCode(id: "GA", name: "Gabon",                    dialCode: "+241", formatPattern: "## ## ## ##"),
        CountryCode(id: "GM", name: "Gambia",                   dialCode: "+220", formatPattern: "### ####"),
        CountryCode(id: "GE", name: "Georgia",                  dialCode: "+995", formatPattern: "### ## ## ##"),
        CountryCode(id: "DE", name: "Germany",                  dialCode: "+49",  formatPattern: "### #######"),
        CountryCode(id: "GH", name: "Ghana",                    dialCode: "+233", formatPattern: "## ### ####"),
        CountryCode(id: "GR", name: "Greece",                   dialCode: "+30",  formatPattern: "### ### ####"),
        CountryCode(id: "GD", name: "Grenada",                  dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "GT", name: "Guatemala",                dialCode: "+502", formatPattern: "#### ####"),
        CountryCode(id: "GN", name: "Guinea",                   dialCode: "+224", formatPattern: "### ## ## ##"),
        CountryCode(id: "GW", name: "Guinea-Bissau",            dialCode: "+245", formatPattern: "### ####"),
        CountryCode(id: "GY", name: "Guyana",                   dialCode: "+592", formatPattern: "### ####"),
        // ── H ──────────────────────────────────────────────────────────────────
        CountryCode(id: "HT", name: "Haiti",                    dialCode: "+509", formatPattern: "## ## ####"),
        CountryCode(id: "HN", name: "Honduras",                 dialCode: "+504", formatPattern: "#### ####"),
        CountryCode(id: "HK", name: "Hong Kong",                dialCode: "+852", formatPattern: "#### ####"),
        CountryCode(id: "HU", name: "Hungary",                  dialCode: "+36",  formatPattern: "## ### ####"),
        // ── I ──────────────────────────────────────────────────────────────────
        CountryCode(id: "IS", name: "Iceland",                  dialCode: "+354", formatPattern: "### ####"),
        CountryCode(id: "IN", name: "India",                    dialCode: "+91",  formatPattern: "##### #####"),
        CountryCode(id: "ID", name: "Indonesia",                dialCode: "+62",  formatPattern: "### #### ####"),
        CountryCode(id: "IR", name: "Iran",                     dialCode: "+98",  formatPattern: "### ### ####"),
        CountryCode(id: "IQ", name: "Iraq",                     dialCode: "+964", formatPattern: "### ### ####"),
        CountryCode(id: "IE", name: "Ireland",                  dialCode: "+353", formatPattern: "## ### ####"),
        CountryCode(id: "IL", name: "Israel",                   dialCode: "+972", formatPattern: "##-###-####"),
        CountryCode(id: "IT", name: "Italy",                    dialCode: "+39",  formatPattern: "### ### ####"),
        CountryCode(id: "CI", name: "Ivory Coast",              dialCode: "+225", formatPattern: "## ## ## ## ##"),
        // ── J ──────────────────────────────────────────────────────────────────
        CountryCode(id: "JM", name: "Jamaica",                  dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "JP", name: "Japan",                    dialCode: "+81",  formatPattern: "##-####-####"),
        CountryCode(id: "JO", name: "Jordan",                   dialCode: "+962", formatPattern: "## ### ####"),
        // ── K ──────────────────────────────────────────────────────────────────
        CountryCode(id: "KZ", name: "Kazakhstan",               dialCode: "+7",   formatPattern: "### ###-##-##"),
        CountryCode(id: "KE", name: "Kenya",                    dialCode: "+254", formatPattern: "### ######"),
        CountryCode(id: "KI", name: "Kiribati",                 dialCode: "+686", formatPattern: "### ####"),
        CountryCode(id: "KW", name: "Kuwait",                   dialCode: "+965", formatPattern: "#### ####"),
        CountryCode(id: "KG", name: "Kyrgyzstan",               dialCode: "+996", formatPattern: "### ### ###"),
        // ── L ──────────────────────────────────────────────────────────────────
        CountryCode(id: "LA", name: "Laos",                     dialCode: "+856", formatPattern: "## ### ####"),
        CountryCode(id: "LV", name: "Latvia",                   dialCode: "+371", formatPattern: "## ### ###"),
        CountryCode(id: "LB", name: "Lebanon",                  dialCode: "+961", formatPattern: "## ### ###"),
        CountryCode(id: "LS", name: "Lesotho",                  dialCode: "+266", formatPattern: "## ### ###"),
        CountryCode(id: "LR", name: "Liberia",                  dialCode: "+231", formatPattern: "## ### ####"),
        CountryCode(id: "LY", name: "Libya",                    dialCode: "+218", formatPattern: "## ### ####"),
        CountryCode(id: "LI", name: "Liechtenstein",            dialCode: "+423", formatPattern: "### ###"),
        CountryCode(id: "LT", name: "Lithuania",                dialCode: "+370", formatPattern: "### ## ###"),
        CountryCode(id: "LU", name: "Luxembourg",               dialCode: "+352", formatPattern: "## ## ## ##"),
        // ── M ──────────────────────────────────────────────────────────────────
        CountryCode(id: "MO", name: "Macao",                    dialCode: "+853", formatPattern: "#### ####"),
        CountryCode(id: "MG", name: "Madagascar",               dialCode: "+261", formatPattern: "## ## ### ##"),
        CountryCode(id: "MW", name: "Malawi",                   dialCode: "+265", formatPattern: "### ### ###"),
        CountryCode(id: "MY", name: "Malaysia",                 dialCode: "+60",  formatPattern: "##-#### ####"),
        CountryCode(id: "MV", name: "Maldives",                 dialCode: "+960", formatPattern: "### ####"),
        CountryCode(id: "ML", name: "Mali",                     dialCode: "+223", formatPattern: "## ## ## ##"),
        CountryCode(id: "MT", name: "Malta",                    dialCode: "+356", formatPattern: "#### ####"),
        CountryCode(id: "MH", name: "Marshall Islands",         dialCode: "+692", formatPattern: "### ####"),
        CountryCode(id: "MR", name: "Mauritania",               dialCode: "+222", formatPattern: "## ## ## ##"),
        CountryCode(id: "MU", name: "Mauritius",                dialCode: "+230", formatPattern: "#### ####"),
        CountryCode(id: "MX", name: "Mexico",                   dialCode: "+52",  formatPattern: "## #### ####"),
        CountryCode(id: "FM", name: "Micronesia",               dialCode: "+691", formatPattern: "### ####"),
        CountryCode(id: "MD", name: "Moldova",                  dialCode: "+373", formatPattern: "## ### ###"),
        CountryCode(id: "MC", name: "Monaco",                   dialCode: "+377", formatPattern: "## ## ## ##"),
        CountryCode(id: "MN", name: "Mongolia",                 dialCode: "+976", formatPattern: "## ## ####"),
        CountryCode(id: "ME", name: "Montenegro",               dialCode: "+382", formatPattern: "## ### ###"),
        CountryCode(id: "MA", name: "Morocco",                  dialCode: "+212", formatPattern: "### ### ###"),
        CountryCode(id: "MZ", name: "Mozambique",               dialCode: "+258", formatPattern: "## ### ####"),
        CountryCode(id: "MM", name: "Myanmar",                  dialCode: "+95",  formatPattern: "## ### ####"),
        // ── N ──────────────────────────────────────────────────────────────────
        CountryCode(id: "NA", name: "Namibia",                  dialCode: "+264", formatPattern: "## ### ####"),
        CountryCode(id: "NR", name: "Nauru",                    dialCode: "+674", formatPattern: "### ####"),
        CountryCode(id: "NP", name: "Nepal",                    dialCode: "+977", formatPattern: "##-### ####"),
        CountryCode(id: "NL", name: "Netherlands",              dialCode: "+31",  formatPattern: "# #### ####"),
        CountryCode(id: "NZ", name: "New Zealand",              dialCode: "+64",  formatPattern: "## ### ####"),
        CountryCode(id: "NI", name: "Nicaragua",                dialCode: "+505", formatPattern: "#### ####"),
        CountryCode(id: "NE", name: "Niger",                    dialCode: "+227", formatPattern: "## ## ## ##"),
        CountryCode(id: "NG", name: "Nigeria",                  dialCode: "+234", formatPattern: "### ### ####"),
        CountryCode(id: "MK", name: "North Macedonia",          dialCode: "+389", formatPattern: "## ### ###"),
        CountryCode(id: "NO", name: "Norway",                   dialCode: "+47",  formatPattern: "#### ####"),
        // ── O ──────────────────────────────────────────────────────────────────
        CountryCode(id: "OM", name: "Oman",                     dialCode: "+968", formatPattern: "#### ####"),
        // ── P ──────────────────────────────────────────────────────────────────
        CountryCode(id: "PK", name: "Pakistan",                 dialCode: "+92",  formatPattern: "### #######"),
        CountryCode(id: "PW", name: "Palau",                    dialCode: "+680", formatPattern: "### ####"),
        CountryCode(id: "PS", name: "Palestine",                dialCode: "+970", formatPattern: "## ### ####"),
        CountryCode(id: "PA", name: "Panama",                   dialCode: "+507", formatPattern: "#### ####"),
        CountryCode(id: "PG", name: "Papua New Guinea",         dialCode: "+675", formatPattern: "### ####"),
        CountryCode(id: "PY", name: "Paraguay",                 dialCode: "+595", formatPattern: "## ### ####"),
        CountryCode(id: "PE", name: "Peru",                     dialCode: "+51",  formatPattern: "### ### ###"),
        CountryCode(id: "PH", name: "Philippines",              dialCode: "+63",  formatPattern: "### ### ####"),
        CountryCode(id: "PL", name: "Poland",                   dialCode: "+48",  formatPattern: "### ### ###"),
        CountryCode(id: "PT", name: "Portugal",                 dialCode: "+351", formatPattern: "### ### ###"),
        CountryCode(id: "PR", name: "Puerto Rico",              dialCode: "+1",   formatPattern: "(###) ###-####"),
        // ── Q ──────────────────────────────────────────────────────────────────
        CountryCode(id: "QA", name: "Qatar",                    dialCode: "+974", formatPattern: "#### ####"),
        // ── R ──────────────────────────────────────────────────────────────────
        CountryCode(id: "RO", name: "Romania",                  dialCode: "+40",  formatPattern: "### ### ###"),
        CountryCode(id: "RU", name: "Russia",                   dialCode: "+7",   formatPattern: "(###) ###-##-##"),
        CountryCode(id: "RW", name: "Rwanda",                   dialCode: "+250", formatPattern: "### ### ###"),
        // ── S ──────────────────────────────────────────────────────────────────
        CountryCode(id: "KN", name: "Saint Kitts and Nevis",    dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "LC", name: "Saint Lucia",              dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "VC", name: "Saint Vincent",            dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "WS", name: "Samoa",                    dialCode: "+685", formatPattern: "### ####"),
        CountryCode(id: "SM", name: "San Marino",               dialCode: "+378", formatPattern: "## ## ## ##"),
        CountryCode(id: "ST", name: "São Tomé and Príncipe",    dialCode: "+239", formatPattern: "### ####"),
        CountryCode(id: "SA", name: "Saudi Arabia",             dialCode: "+966", formatPattern: "## ### ####"),
        CountryCode(id: "SN", name: "Senegal",                  dialCode: "+221", formatPattern: "## ### ## ##"),
        CountryCode(id: "RS", name: "Serbia",                   dialCode: "+381", formatPattern: "## ### ####"),
        CountryCode(id: "SC", name: "Seychelles",               dialCode: "+248", formatPattern: "#### ####"),
        CountryCode(id: "SL", name: "Sierra Leone",             dialCode: "+232", formatPattern: "## ### ###"),
        CountryCode(id: "SG", name: "Singapore",                dialCode: "+65",  formatPattern: "#### ####"),
        CountryCode(id: "SK", name: "Slovakia",                 dialCode: "+421", formatPattern: "### ### ###"),
        CountryCode(id: "SI", name: "Slovenia",                 dialCode: "+386", formatPattern: "## ### ###"),
        CountryCode(id: "SB", name: "Solomon Islands",          dialCode: "+677", formatPattern: "### ###"),
        CountryCode(id: "SO", name: "Somalia",                  dialCode: "+252", formatPattern: "## ### ###"),
        CountryCode(id: "ZA", name: "South Africa",             dialCode: "+27",  formatPattern: "## ### ####"),
        CountryCode(id: "SS", name: "South Sudan",              dialCode: "+211", formatPattern: "## ### ####"),
        CountryCode(id: "KR", name: "South Korea",              dialCode: "+82",  formatPattern: "##-####-####"),
        CountryCode(id: "ES", name: "Spain",                    dialCode: "+34",  formatPattern: "### ### ###"),
        CountryCode(id: "LK", name: "Sri Lanka",                dialCode: "+94",  formatPattern: "## ### ####"),
        CountryCode(id: "SD", name: "Sudan",                    dialCode: "+249", formatPattern: "## ### ####"),
        CountryCode(id: "SR", name: "Suriname",                 dialCode: "+597", formatPattern: "### ####"),
        CountryCode(id: "SE", name: "Sweden",                   dialCode: "+46",  formatPattern: "##-### ## ##"),
        CountryCode(id: "CH", name: "Switzerland",              dialCode: "+41",  formatPattern: "## ### ## ##"),
        CountryCode(id: "SY", name: "Syria",                    dialCode: "+963", formatPattern: "## ### ####"),
        // ── T ──────────────────────────────────────────────────────────────────
        CountryCode(id: "TW", name: "Taiwan",                   dialCode: "+886", formatPattern: "### ### ###"),
        CountryCode(id: "TJ", name: "Tajikistan",               dialCode: "+992", formatPattern: "## ### ####"),
        CountryCode(id: "TZ", name: "Tanzania",                 dialCode: "+255", formatPattern: "### ### ###"),
        CountryCode(id: "TH", name: "Thailand",                 dialCode: "+66",  formatPattern: "##-### ####"),
        CountryCode(id: "TL", name: "Timor-Leste",              dialCode: "+670", formatPattern: "### ####"),
        CountryCode(id: "TG", name: "Togo",                     dialCode: "+228", formatPattern: "## ## ## ##"),
        CountryCode(id: "TO", name: "Tonga",                    dialCode: "+676", formatPattern: "### ####"),
        CountryCode(id: "TT", name: "Trinidad and Tobago",      dialCode: "+1",   formatPattern: "(###) ###-####"),
        CountryCode(id: "TN", name: "Tunisia",                  dialCode: "+216", formatPattern: "## ### ###"),
        CountryCode(id: "TR", name: "Turkey",                   dialCode: "+90",  formatPattern: "### ### ####"),
        CountryCode(id: "TM", name: "Turkmenistan",             dialCode: "+993", formatPattern: "## ### ####"),
        CountryCode(id: "TV", name: "Tuvalu",                   dialCode: "+688", formatPattern: "## ###"),
        // ── U ──────────────────────────────────────────────────────────────────
        CountryCode(id: "UG", name: "Uganda",                   dialCode: "+256", formatPattern: "### ### ###"),
        CountryCode(id: "UA", name: "Ukraine",                  dialCode: "+380", formatPattern: "## ### ## ##"),
        CountryCode(id: "AE", name: "UAE",                      dialCode: "+971", formatPattern: "## ### ####"),
        CountryCode(id: "UY", name: "Uruguay",                  dialCode: "+598", formatPattern: "## ### ## ##"),
        CountryCode(id: "UZ", name: "Uzbekistan",               dialCode: "+998", formatPattern: "## ### ## ##"),
        // ── V ──────────────────────────────────────────────────────────────────
        CountryCode(id: "VU", name: "Vanuatu",                  dialCode: "+678", formatPattern: "### ###"),
        CountryCode(id: "VA", name: "Vatican City",             dialCode: "+379", formatPattern: "## ### ####"),
        CountryCode(id: "VE", name: "Venezuela",                dialCode: "+58",  formatPattern: "### ### ####"),
        CountryCode(id: "VN", name: "Vietnam",                  dialCode: "+84",  formatPattern: "### ### ###"),
        // ── Y ──────────────────────────────────────────────────────────────────
        CountryCode(id: "YE", name: "Yemen",                    dialCode: "+967", formatPattern: "### ### ###"),
        // ── Z ──────────────────────────────────────────────────────────────────
        CountryCode(id: "ZM", name: "Zambia",                   dialCode: "+260", formatPattern: "## ### ####"),
        CountryCode(id: "ZW", name: "Zimbabwe",                 dialCode: "+263", formatPattern: "## ### ####"),
    ]
}
