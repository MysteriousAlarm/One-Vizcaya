import 'package:flutter/material.dart';

/// Curated directory of common government offices/services for the Citizen Guide
/// ("Locate") screen.
///
/// ⚠️ DATA-INTEGRITY NOTE (read before release):
/// Official **websites** are stable and safe to ship. Local **branch addresses,
/// office hours, and phone numbers** for Nueva Vizcaya are intentionally left as
/// placeholders (`address: null`, `phone: null`) because publishing an unverified
/// number/address in a civic app is harmful. Fill these with LGU-verified details
/// before release. Any phone number ending in `#` is treated as a non-dialable
/// placeholder (same convention as the Emergency Contacts screen).
class GovOffice {
  final String name;
  final String? address; // null/empty → "being verified"
  final String? hours;
  final String? website; // safe to ship (official site)
  final String? phone; // null/empty or ending in '#' → non-dialable placeholder
  final String? email;

  const GovOffice({
    required this.name,
    this.address,
    this.hours,
    this.website,
    this.phone,
    this.email,
  });

  bool get hasDialablePhone =>
      phone != null && phone!.trim().isNotEmpty && !phone!.contains('#');
  bool get hasAddress => address != null && address!.trim().isNotEmpty;
}

class OfficeCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<GovOffice> offices;
  const OfficeCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.offices,
  });
}

/// The directory. Websites are verified/official; local address/hours/phone are
/// placeholders for the LGU to fill (see note above).
const List<OfficeCategory> kOfficeDirectory = [
  OfficeCategory(
    title: 'ID Registration & Licenses',
    icon: Icons.badge_rounded,
    color: Color(0xFF1565C0),
    offices: [
      GovOffice(
        name: 'NBI — National Bureau of Investigation',
        website: 'https://nbi.gov.ph',
      ),
      GovOffice(
        name: 'LTO — Land Transportation Office',
        website: 'https://lto.gov.ph',
      ),
      GovOffice(
        name: 'PSA — Philippine Statistics Authority (birth/marriage records)',
        website: 'https://psa.gov.ph',
      ),
      GovOffice(
        name: 'DFA — Passport / Consular Services',
        website: 'https://dfa.gov.ph',
      ),
      GovOffice(
        name: 'COMELEC — Voter Registration',
        website: 'https://comelec.gov.ph',
      ),
    ],
  ),
  OfficeCategory(
    title: 'Benefits & Contributions',
    icon: Icons.savings_rounded,
    color: Color(0xFF2E7D32),
    offices: [
      GovOffice(
        name: 'SSS — Social Security System',
        website: 'https://www.sss.gov.ph',
      ),
      GovOffice(
        name: 'Pag-IBIG Fund (HDMF)',
        website: 'https://www.pagibigfund.gov.ph',
      ),
      GovOffice(
        name: 'PhilHealth',
        website: 'https://www.philhealth.gov.ph',
      ),
    ],
  ),
  OfficeCategory(
    title: 'Financial & Social Support',
    icon: Icons.volunteer_activism_rounded,
    color: Color(0xFF6A1B9A),
    offices: [
      GovOffice(
        name: 'DSWD — Social Welfare & Development (4Ps, assistance)',
        website: 'https://www.dswd.gov.ph',
      ),
      GovOffice(
        name: 'BIR — Bureau of Internal Revenue',
        website: 'https://www.bir.gov.ph',
      ),
    ],
  ),
  OfficeCategory(
    title: 'Health',
    icon: Icons.local_hospital_rounded,
    color: Color(0xFFC62828),
    offices: [
      GovOffice(
        name: 'DOH — Department of Health',
        website: 'https://doh.gov.ph',
      ),
      GovOffice(
        name: 'Provincial Health Office — Nueva Vizcaya',
        // Local details to be verified & filled by the LGU.
      ),
    ],
  ),
  OfficeCategory(
    title: 'Local Government',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF00695C),
    offices: [
      GovOffice(
        name: 'Provincial Capitol — Nueva Vizcaya',
        website: 'https://nuevavizcaya.gov.ph',
      ),
      GovOffice(
        name: 'Your Municipal Hall',
        // Fill per-municipality; see Emergency Contacts for the hotline pattern.
      ),
    ],
  ),
];
