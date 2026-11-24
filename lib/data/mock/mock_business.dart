import '../models/automation_rule.dart';
import '../models/common.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/quotation.dart';
import '../models/support.dart';
import 'mock_crm.dart';

LineItem _li(String id, String desc, double qty, double price) =>
    LineItem(id: id, description: desc, quantity: qty, unitPrice: price);

const _terms = '50% advance to begin work. Balance on delivery. Payment within 14 days of invoice date. '
    'Additional revisions beyond scope are billed separately.';

abstract final class MockBusiness {
  static List<Quotation> quotations() => [
        Quotation(
          id: 'q1',
          number: 'QT-2026-001',
          clientId: 'c1',
          title: 'E-commerce storefront redesign',
          items: [
            _li('1', 'UX research & wireframes', 1, 60000),
            _li('2', 'UI design system', 1, 60000),
            _li('3', 'Storefront development', 1, 70000),
            _li('4', 'QA, launch & handover', 1, 50000),
          ],
          issueDate: day(-70),
          validUntil: day(-55),
          status: QuotationStatus.accepted,
          notes: 'Includes up to 2 rounds of revisions per milestone.',
          terms: _terms,
        ),
        Quotation(
          id: 'q2',
          number: 'QT-2026-002',
          clientId: 'c2',
          title: 'Class booking mobile app',
          items: [
            _li('1', 'Discovery & user flows', 1, 40000),
            _li('2', 'Core booking module', 1, 70000),
            _li('3', 'Payments & memberships', 1, 40000),
            _li('4', 'Store release', 1, 30000),
          ],
          issueDate: day(-55),
          validUntil: day(-40),
          status: QuotationStatus.accepted,
          terms: _terms,
        ),
        Quotation(
          id: 'q3',
          number: 'QT-2026-003',
          clientId: 'c8',
          title: 'Portfolio website',
          items: [_li('1', 'Design & prototype', 1, 30000), _li('2', 'Development & CMS setup', 1, 45000)],
          issueDate: day(-28),
          validUntil: day(-14),
          status: QuotationStatus.accepted,
          discountPercent: 0,
          terms: _terms,
        ),
        Quotation(
          id: 'q4',
          number: 'QT-2026-004',
          clientId: 'c5',
          title: 'Analytics integration add-on',
          items: [_li('1', 'Event tracking setup', 1, 18000), _li('2', 'Dashboard configuration', 1, 12000)],
          issueDate: day(-1),
          validUntil: day(13),
          status: QuotationStatus.draft,
          terms: _terms,
        ),
        Quotation(
          id: 'q5',
          number: 'QT-2026-005',
          clientId: 'c1',
          title: 'SEO & performance add-on',
          items: [_li('1', 'Technical SEO audit', 1, 20000), _li('2', 'Core Web Vitals optimisation', 1, 25000)],
          issueDate: day(-20),
          validUntil: day(-3),
          status: QuotationStatus.sent,
          discountPercent: 5,
          notes: 'Offer includes a 5% loyalty discount.',
          terms: _terms,
        ),
        Quotation(
          id: 'q6',
          number: 'QT-2026-006',
          clientId: 'c4',
          title: 'Learning management portal',
          items: [
            _li('1', 'Discovery workshop', 1, 50000),
            _li('2', 'MVP design & build', 1, 250000),
            _li('3', 'Video hosting integration', 1, 60000),
            _li('4', 'Admin dashboard', 1, 90000),
          ],
          issueDate: day(-4),
          validUntil: day(10),
          status: QuotationStatus.sent,
          discountPercent: 3,
          notes: 'Timeline: 16 weeks from kickoff.',
          terms: _terms,
        ),
        Quotation(
          id: 'q7',
          number: 'QT-2026-007',
          clientId: 'c6',
          title: 'Product catalogue extension',
          items: [_li('1', 'Catalogue filters & search', 1, 28000), _li('2', 'Bulk upload tool', 1, 17000)],
          issueDate: day(-35),
          validUntil: day(-20),
          status: QuotationStatus.rejected,
          terms: _terms,
        ),
      ];

  static Invoice _inv({
    required String id,
    required String number,
    required String clientId,
    String? projectId,
    required List<LineItem> items,
    required int issuedDaysAgo,
    required int dueInDays,
    InvoiceStatus status = InvoiceStatus.sent,
    List<(int daysAgo, double fraction, PaymentMethod method)> pays = const [],
    String notes = '',
  }) {
    final base = Invoice(
      id: id,
      number: number,
      clientId: clientId,
      projectId: projectId,
      items: items,
      issueDate: day(-issuedDaysAgo),
      dueDate: day(dueInDays),
      status: status,
      notes: notes,
    );
    final total = base.total;
    var n = 0;
    return base.copyWith(
      payments: [
        for (final p in pays)
          Payment(
            id: '${id}_p${n++}',
            invoiceId: id,
            amount: (total * p.$2).roundToDouble(),
            date: day(-p.$1, 12),
            method: p.$3,
            reference: 'TXN${id.hashCode.abs() % 100000 + n}',
          ),
      ],
    );
  }

  static List<Invoice> invoices() => [
        _inv(id: 'inv19', number: 'INV-2026-019', clientId: 'c4', items: [_li('1', 'Discovery workshop (advance)', 1, 25000)], issuedDaysAgo: 0, dueInDays: 14, status: InvoiceStatus.draft),
        _inv(id: 'inv18', number: 'INV-2026-018', clientId: 'c2', projectId: 'p2', items: [_li('1', 'Core booking module: milestone 2', 1, 55000)], issuedDaysAgo: 12, dueInDays: 3),
        _inv(
          id: 'inv17',
          number: 'INV-2026-017',
          clientId: 'c6',
          projectId: 'p6',
          items: [_li('1', 'Brand-aligned website design', 1, 45000)],
          issuedDaysAgo: 40,
          dueInDays: -10,
          notes: 'Payment reminder sent on the 5th.',
        ),
        _inv(id: 'inv16', number: 'INV-2026-016', clientId: 'c8', projectId: 'p7', items: [_li('1', 'Design & prototype (advance 50%)', 1, 30000)], issuedDaysAgo: 5, dueInDays: 9),
        _inv(
          id: 'inv15',
          number: 'INV-2026-015',
          clientId: 'c3',
          projectId: 'p3',
          items: [_li('1', 'Dashboard UI milestone', 1, 100000)],
          issuedDaysAgo: 20,
          dueInDays: 5,
          pays: [(10, 0.5, PaymentMethod.bankTransfer)],
        ),
        _inv(
          id: 'inv14',
          number: 'INV-2026-014',
          clientId: 'c1',
          projectId: 'p1',
          items: [_li('1', 'UI design system', 1, 60000), _li('2', 'Design tokens & component library', 1, 20000)],
          issuedDaysAgo: 35,
          dueInDays: -21,
          pays: [(25, 0.5, PaymentMethod.upi)],
        ),
        _inv(id: 'inv13', number: 'INV-2026-013', clientId: 'c2', projectId: 'p2', items: [_li('1', 'Discovery & user flows', 1, 60000)], issuedDaysAgo: 45, dueInDays: -31, pays: [(38, 1, PaymentMethod.upi)]),
        _inv(id: 'inv12', number: 'INV-2026-012', clientId: 'c3', projectId: 'p3', items: [_li('1', 'Data model & API milestone', 1, 120000)], issuedDaysAgo: 80, dueInDays: -66, pays: [(70, 1, PaymentMethod.bankTransfer)]),
        _inv(id: 'inv11', number: 'INV-2026-011', clientId: 'c1', projectId: 'p1', items: [_li('1', 'UX research', 1, 60000), _li('2', 'Wireframes', 1, 40000)], issuedDaysAgo: 75, dueInDays: -61, pays: [(66, 1, PaymentMethod.bankTransfer)]),
        _inv(
          id: 'inv9',
          number: 'INV-2026-009',
          clientId: 'c5',
          projectId: 'p5',
          items: [_li('1', 'Landing page design', 1, 40000), _li('2', 'Development & launch', 1, 50000)],
          issuedDaysAgo: 118,
          dueInDays: -104,
          pays: [(112, 0.6, PaymentMethod.bankTransfer), (95, 0.4, PaymentMethod.upi)],
        ),
        _inv(id: 'inv8', number: 'INV-2026-008', clientId: 'c2', items: [_li('1', 'Product consulting (2 days)', 2, 10000)], issuedDaysAgo: 140, dueInDays: -126, pays: [(135, 1, PaymentMethod.upi)]),
        _inv(id: 'inv6', number: 'INV-2026-006', clientId: 'c6', items: [_li('1', 'Brand identity kit', 1, 55000)], issuedDaysAgo: 150, dueInDays: -136, pays: [(145, 1, PaymentMethod.bankTransfer)]),
        _inv(id: 'inv3', number: 'INV-2026-003', clientId: 'c7', items: [_li('1', 'Monthly retainer', 1, 30000)], issuedDaysAgo: 175, dueInDays: -161, pays: [(168, 1, PaymentMethod.bankTransfer)]),
      ];

  static Expense _e(String id, String title, double amount, ExpenseCategory c, int daysAgo, [String vendor = '', String? receipt]) =>
      Expense(id: id, title: title, amount: amount, category: c, date: day(-daysAgo), vendor: vendor, receiptName: receipt);

  static List<Expense> expenses() => [
        _e('e1', 'Figma Professional', 1250, ExpenseCategory.subscriptions, 3, 'Figma', 'figma-oct.pdf'),
        _e('e2', 'Co-working desk: October', 6500, ExpenseCategory.office, 5, 'IndiHub Cowork', 'cowork-oct.pdf'),
        _e('e3', 'Google Workspace', 960, ExpenseCategory.software, 8, 'Google'),
        _e('e4', 'Google Ads: portfolio campaign', 4500, ExpenseCategory.marketing, 11, 'Google Ads'),
        _e('e5', 'Client visit travel (Mumbai)', 9800, ExpenseCategory.travel, 22, 'IndiGo', 'flight-mumbai.jpg'),
        _e('e6', 'Cloud hosting (AWS)', 3200, ExpenseCategory.software, 14, 'AWS'),
        _e('e7', 'Flutter advanced course', 7499, ExpenseCategory.education, 26, 'Udemy'),
        _e('e8', 'Figma Professional', 1250, ExpenseCategory.subscriptions, 33, 'Figma'),
        _e('e9', 'Co-working desk: September', 6500, ExpenseCategory.office, 35, 'IndiHub Cowork'),
        _e('e10', 'Domain & SSL renewals', 2400, ExpenseCategory.software, 40, 'GoDaddy'),
        _e('e11', 'Professional tax & CA fees', 8000, ExpenseCategory.taxes, 44, 'CA Ramesh & Co.', 'ca-invoice.pdf'),
        _e('e12', 'Cloud hosting (AWS)', 2900, ExpenseCategory.software, 45, 'AWS'),
        _e('e13', 'LinkedIn Premium', 2100, ExpenseCategory.marketing, 48, 'LinkedIn'),
        _e('e14', 'Figma Professional', 1250, ExpenseCategory.subscriptions, 63, 'Figma'),
        _e('e15', 'Co-working desk: August', 6500, ExpenseCategory.office, 65, 'IndiHub Cowork'),
        _e('e16', 'Monitor 27" 4K', 28500, ExpenseCategory.hardware, 70, 'Amazon', 'monitor-receipt.pdf'),
        _e('e17', 'Cloud hosting (AWS)', 3100, ExpenseCategory.software, 75, 'AWS'),
        _e('e18', 'Figma Professional', 1250, ExpenseCategory.subscriptions, 93, 'Figma'),
        _e('e19', 'Co-working desk: July', 6500, ExpenseCategory.office, 95, 'IndiHub Cowork'),
        _e('e20', 'Design conference ticket', 12000, ExpenseCategory.education, 100, 'UX India'),
        _e('e21', 'MacBook Air M3', 98000, ExpenseCategory.hardware, 118, 'Apple Store', 'macbook-invoice.pdf'),
        _e('e22', 'Co-working desk: June', 6500, ExpenseCategory.office, 125, 'IndiHub Cowork'),
        _e('e23', 'Figma Professional', 1250, ExpenseCategory.subscriptions, 123, 'Figma'),
        _e('e24', 'Social media ads', 5500, ExpenseCategory.marketing, 140, 'Meta Ads'),
        _e('e25', 'Co-working desk: May', 6500, ExpenseCategory.office, 155, 'IndiHub Cowork'),
        _e('e26', 'Accounting software', 3600, ExpenseCategory.software, 160, 'Zoho Books'),
      ];

  static List<Ticket> tickets() => [
        Ticket(
          id: 'tk1',
          assigneeId: 'tm2',
          number: 'TKT-1001',
          title: 'Checkout payment webhook failing intermittently',
          clientId: 'c1',
          description: 'Some orders stay in "pending" even after Razorpay confirms payment. Happens roughly 1 in 20 orders.',
          priority: Priority.urgent,
          status: TicketStatus.inProgress,
          createdAt: day(-2, 9),
          notes: [
            Note(id: 'tkn1', text: 'Ticket created. Reproduced on staging.', at: day(-2, 10)),
            Note(id: 'tkn2', text: 'Root cause looks like webhook retry timing. Adding idempotency key.', at: day(-1, 16)),
          ],
        ),
        Ticket(
          id: 'tk2',
          assigneeId: 'tm2',
          number: 'TKT-1002',
          title: 'Push notifications not delivered on iOS',
          clientId: 'c2',
          description: 'Class reminder notifications arrive on Android but not on iPhone devices.',
          priority: Priority.high,
          status: TicketStatus.open,
          createdAt: day(-1, 14),
          notes: [Note(id: 'tkn3', text: 'Ticket created from client email.', at: day(-1, 14))],
        ),
        Ticket(
          id: 'tk3',
          assigneeId: 'tm2',
          number: 'TKT-1003',
          title: 'Add CSV export for shipment reports',
          clientId: 'c3',
          description: 'Client wants to export filtered shipment tables as CSV for accounting.',
          priority: Priority.medium,
          status: TicketStatus.waiting,
          createdAt: day(-8, 11),
          notes: [
            Note(id: 'tkn4', text: 'Requested sample data and required columns.', at: day(-7, 12)),
            Note(id: 'tkn5', text: 'Waiting on client to confirm column list.', at: day(-4, 10)),
          ],
        ),
        Ticket(
          id: 'tk4',
          assigneeId: 'tm5',
          number: 'TKT-1004',
          title: 'Update contact form recipient email',
          clientId: 'c5',
          description: 'Route enquiries to sales@zenithfin.io instead of the old address.',
          priority: Priority.low,
          status: TicketStatus.resolved,
          createdAt: day(-12, 10),
          notes: [
            Note(id: 'tkn6', text: 'Updated form handler and tested delivery.', at: day(-11, 17)),
            Note(id: 'tkn7', text: 'Resolved. Client confirmed new enquiries are arriving.', at: day(-10, 9)),
          ],
        ),
        Ticket(
          id: 'tk5',
          assigneeId: 'tm5',
          number: 'TKT-1005',
          title: 'SSL certificate renewal',
          clientId: 'c8',
          description: 'Certificate expires in two weeks.',
          priority: Priority.medium,
          status: TicketStatus.closed,
          createdAt: day(-20, 10),
          notes: [Note(id: 'tkn8', text: 'Renewed certificate and verified HTTPS. Closed.', at: day(-19, 11))],
        ),
        Ticket(
          id: 'tk6',
          assigneeId: 'tm5',
          number: 'TKT-1006',
          title: 'Change homepage hero banner',
          clientId: 'c6',
          description: 'Replace hero image and headline for the festive season campaign.',
          priority: Priority.low,
          status: TicketStatus.open,
          createdAt: day(0, 8),
          notes: [Note(id: 'tkn9', text: 'Ticket created.', at: day(0, 8))],
        ),
      ];

  static List<MaintenancePlan> plans() => [
        MaintenancePlan(
          id: 'mp1',
          clientId: 'c1',
          name: 'Growth Care Plan',
          monthlyFee: 12000,
          nextReview: day(12),
          includes: ['Priority support (4h response)', '10 hrs changes / month', 'Monthly performance report', 'Security updates'],
        ),
        MaintenancePlan(
          id: 'mp2',
          clientId: 'c2',
          name: 'Essential Care Plan',
          monthlyFee: 6000,
          nextReview: day(20),
          includes: ['Email support (24h response)', '4 hrs changes / month', 'Uptime monitoring'],
        ),
        MaintenancePlan(
          id: 'mp3',
          clientId: 'c5',
          name: 'Basic Hosting & Care',
          monthlyFee: 3500,
          nextReview: day(-5),
          includes: ['Hosting & SSL', '2 hrs changes / month'],
          active: false,
        ),
      ];

  static List<AutomationRule> automations() => [
        AutomationRule(
          id: 'au1',
          name: 'New lead follow-up',
          trigger: 'New lead is added',
          action: 'Create a follow-up task for tomorrow',
          kind: AutomationKind.lead,
          runs: 18,
          lastRun: day(0, 8),
        ),
        AutomationRule(
          id: 'au2',
          name: 'Follow-up reminder',
          trigger: 'Follow-up becomes due',
          action: 'Show a reminder on the dashboard',
          kind: AutomationKind.followUp,
          runs: 42,
          lastRun: day(0, 9),
        ),
        AutomationRule(
          id: 'au3',
          name: 'Quotation accepted',
          trigger: 'Quotation is accepted',
          action: 'Prepare a project draft from the quotation',
          kind: AutomationKind.quotation,
          runs: 6,
          lastRun: day(-28, 14),
        ),
        AutomationRule(
          id: 'au4',
          name: 'Overdue invoice reminder',
          trigger: 'Invoice becomes overdue',
          action: 'Show a payment reminder prompt',
          kind: AutomationKind.invoice,
          runs: 9,
          lastRun: day(-2, 10),
        ),
        AutomationRule(
          id: 'au5',
          name: 'Deadline alert',
          trigger: 'Task deadline is approaching (24h)',
          action: 'Send a notification',
          kind: AutomationKind.task,
          runs: 31,
          lastRun: day(0, 7),
        ),
        AutomationRule(
          id: 'au6',
          name: 'Weekly business summary',
          trigger: 'Every Monday at 8:00 AM',
          action: 'Display the weekly business report',
          kind: AutomationKind.report,
          enabled: false,
          runs: 12,
          lastRun: day(-3, 8),
        ),
      ];

  static List<ActivityEntry> activity() => [
        ActivityEntry(id: 'g1', title: 'Payment received', detail: 'Logistics Dashboard milestone · partial payment', at: day(-10, 12), kind: ActivityKind.payment),
        ActivityEntry(id: 'g2', title: 'Ticket opened by Bloom Wellness', detail: 'Push notifications not delivered on iOS', at: day(-1, 14), kind: ActivityKind.support),
        ActivityEntry(id: 'g3', title: 'New lead from Upwork', detail: 'Dev Malhotra · CodeCrate', at: day(0, 8), kind: ActivityKind.lead),
        ActivityEntry(id: 'g4', title: 'Quotation sent', detail: 'QT-2026-006 to Brightpath Education', at: day(-4, 16), kind: ActivityKind.quotation),
        ActivityEntry(id: 'g5', title: 'Milestone completed', detail: 'UI design system · E-commerce Redesign', at: day(-15, 17), kind: ActivityKind.project),
        ActivityEntry(id: 'g6', title: 'Invoice INV-2026-016 sent', detail: 'Urban Nest Interiors', at: day(-5, 10), kind: ActivityKind.invoice),
      ];

  static List<AppNotification> notifications() => [
        AppNotification(id: 'nt1', title: 'Follow-up due today', body: 'Call Neha Verma (Craftly) at 4:00 PM', at: day(0, 8), kind: ActivityKind.lead, route: '/leads/l1'),
        AppNotification(id: 'nt2', title: 'Invoice overdue', body: 'INV-2026-017 · GreenLeaf Organics is 10 days overdue', at: day(0, 7), kind: ActivityKind.invoice, route: '/invoices/inv17'),
        AppNotification(id: 'nt3', title: 'Task deadline approaching', body: 'Review storefront PR for Nova checkout is due today', at: day(0, 7), kind: ActivityKind.task, route: '/tasks/t2'),
        AppNotification(id: 'nt4', title: 'New support ticket', body: 'Bloom Wellness: Push notifications not delivered on iOS', at: day(-1, 14), kind: ActivityKind.support, route: '/support/tk2', read: true),
        AppNotification(id: 'nt5', title: 'Quotation expired', body: 'QT-2026-005 to Nova Retail has passed its validity date', at: day(-3, 9), kind: ActivityKind.quotation, route: '/quotations/q5', read: true),
        AppNotification(id: 'nt6', title: 'Weekly summary ready', body: 'Revenue up 12% vs last week. View your report.', at: day(-3, 8), kind: ActivityKind.automation, route: '/reports', read: true),
      ];
}
