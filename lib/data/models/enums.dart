// Domain enumerations. Pure Dart: UI colours/icons live in
// `core/components/status_style.dart` so the data layer stays UI-free.

enum LeadStatus {
  newLead('New'),
  contacted('Contacted'),
  followUp('Follow-up'),
  proposalSent('Proposal Sent'),
  negotiation('Negotiation'),
  won('Won'),
  lost('Lost');

  const LeadStatus(this.label);
  final String label;
  bool get isOpen => this != won && this != lost;
}

enum LeadSource {
  website('Website enquiry'),
  whatsapp('WhatsApp'),
  instagram('Instagram'),
  referral('Referral'),
  linkedin('LinkedIn'),
  upwork('Upwork'),
  coldOutreach('Cold Outreach'),
  googleMaps('Google Maps'),
  directory('Business directory'),
  other('Other');

  const LeadSource(this.label);
  final String label;
}

/// The service a lead is asking about: the same three services ADVIO lists on its website.
enum ServiceInterest {
  website('Website Development', 'Website'),
  software('Custom Software / Web Application', 'Software'),
  automation('Business Automation', 'Automation'),
  other('Other', 'Other');

  const ServiceInterest(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

/// Budget ranges offered on the website enquiry form.
enum BudgetBand {
  under25k('Under ₹25,000', 20000),
  from25kTo60k('₹25,000 – ₹60,000', 42500),
  from60kTo150k('₹60,000 – ₹1,50,000', 105000),
  above150k('₹1,50,000+', 200000),
  unsure('Not sure yet', 0);

  const BudgetBand(this.label, this.typicalValue);
  final String label;

  /// A rough figure to pre-fill the estimated deal value with.
  final double typicalValue;
}

enum FollowUpType {
  call('Call'),
  email('Email'),
  meeting('Meeting'),
  whatsapp('WhatsApp');

  const FollowUpType(this.label);
  final String label;
}

enum ClientStatus {
  active('Active'),
  inactive('Inactive');

  const ClientStatus(this.label);
  final String label;
}

enum ProjectStatus {
  planned('Planned'),
  active('Active'),
  onHold('On Hold'),
  completed('Completed'),
  cancelled('Cancelled');

  const ProjectStatus(this.label);
  final String label;
}

enum TaskStatus {
  todo('To Do'),
  inProgress('In Progress'),
  blocked('Blocked'),
  completed('Completed');

  const TaskStatus(this.label);
  final String label;
}

enum Priority {
  low('Low'),
  medium('Medium'),
  high('High'),
  urgent('Urgent');

  const Priority(this.label);
  final String label;
}

enum QuotationStatus {
  draft('Draft'),
  sent('Sent'),
  accepted('Accepted'),
  rejected('Rejected'),
  expired('Expired');

  const QuotationStatus(this.label);
  final String label;
}

enum InvoiceStatus {
  draft('Draft'),
  sent('Sent'),
  partiallyPaid('Partially Paid'),
  paid('Paid'),
  overdue('Overdue'),
  voided('Void');

  const InvoiceStatus(this.label);
  final String label;
}

enum PaymentMethod {
  bankTransfer('Bank Transfer'),
  upi('UPI'),
  card('Card'),
  cash('Cash'),
  cheque('Cheque'),
  paypal('PayPal');

  const PaymentMethod(this.label);
  final String label;
}

enum ExpenseCategory {
  software('Software'),
  hardware('Hardware'),
  marketing('Marketing'),
  travel('Travel'),
  office('Office'),
  subscriptions('Subscriptions'),
  education('Education'),
  taxes('Taxes & Fees'),
  other('Other');

  const ExpenseCategory(this.label);
  final String label;
}

enum TicketStatus {
  open('Open'),
  inProgress('In Progress'),
  waiting('Waiting on Client'),
  resolved('Resolved'),
  closed('Closed');

  const TicketStatus(this.label);
  final String label;
  bool get isActive => this != resolved && this != closed;
}

enum ActivityKind { lead, client, project, task, quotation, invoice, payment, expense, support, note, automation }

enum AutomationKind { lead, followUp, quotation, invoice, task, report }
