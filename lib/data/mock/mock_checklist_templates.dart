import '../models/checklist.dart';
import 'mock_crm.dart';

// Compact builders so the template content below reads like an outline.

const _none = EvidenceType.none;
const _url = EvidenceType.url;
const _file = EvidenceType.file;
const _note = EvidenceType.note;

TemplateItem _i(
  String title, {
  String d = '',
  bool req = true,
  EvidenceType ev = _none,
  String hint = '',
  bool client = false,
}) =>
    TemplateItem(id: '', title: title, description: d, isRequired: req, evidenceType: ev, evidenceHint: hint, clientDependent: client);

TemplateStage _s(String name, String description, List<TemplateItem> items) =>
    TemplateStage(id: '', name: name, description: description, items: items);

/// Gives every stage and item a stable id and spreads default due dates
/// (`step` days apart) across the whole template.
ChecklistTemplate _tpl({
  required String id,
  required String name,
  required ServiceCategory category,
  required String description,
  required List<TemplateStage> stages,
  required int updatedDaysAgo,
  int step = 2,
}) {
  var offset = 0;
  return ChecklistTemplate(
    id: id,
    name: name,
    category: category,
    description: description,
    updatedAt: day(-updatedDaysAgo),
    stages: [
      for (var si = 0; si < stages.length; si++)
        stages[si].copyWith(items: [
          for (var ii = 0; ii < stages[si].items.length; ii++)
            stages[si].items[ii].copyWith(dueOffsetDays: offset += step),
        ]).withId('${id}_s${si + 1}'),
    ],
  );
}

extension on TemplateStage {
  TemplateStage withId(String stageId) => TemplateStage(
        id: stageId,
        name: name,
        description: description,
        items: [
          for (var ii = 0; ii < items.length; ii++)
            TemplateItem(
              id: '${stageId}_i${ii + 1}',
              title: items[ii].title,
              description: items[ii].description,
              isRequired: items[ii].isRequired,
              evidenceType: items[ii].evidenceType,
              evidenceHint: items[ii].evidenceHint,
              clientDependent: items[ii].clientDependent,
              dueOffsetDays: items[ii].dueOffsetDays,
            ),
        ],
      );
}

// Stages every project-style service starts with.
TemplateStage _discovery({String name = 'Discovery and Proposal', List<TemplateItem> extra = const []}) => _s(
      name,
      'Understand the problem, agree the scope and send a proposal.',
      [
        _i('Collect client requirements', d: 'Goals, audience, features, budget and timeline.', ev: _note, hint: 'Requirements summary', client: true),
        ...extra,
        _i('Define scope and deliverables', d: 'Write down what is in and out of scope.', ev: _note, hint: 'Scope summary'),
        _i('Send proposal and quotation', ev: _file, hint: 'Proposal document'),
      ],
    );

TemplateStage _contract() => _s(
      'Contract and Kickoff',
      'Paperwork, advance payment and a clear start.',
      [
        _i('Get signed agreement', d: 'Signed by both parties before work begins.', ev: _file, hint: 'Signed agreement', client: true),
        _i('Receive advance payment', ev: _note, hint: 'Payment reference', client: true),
        _i('Hold kickoff call', d: 'Confirm timeline, contacts and how approvals will work.', ev: _note, hint: 'Kickoff notes'),
      ],
    );

TemplateStage _closure({List<TemplateItem> extra = const []}) => _s(
      'Handover and Closure',
      'Final payment, handover and wrapping up.',
      [
        _i('Verify final payment', ev: _note, hint: 'Payment confirmation'),
        ...extra,
        _i('Prepare handover documentation', ev: _file, hint: 'Handover document'),
        _i('Request testimonial', req: false, client: true),
      ],
    );

abstract final class MockChecklistTemplates {
  static List<ChecklistTemplate> all() => [staticWebsite(), ecommerce(), crm(), mobileApp(), workflow(), maintenance()];

  static ChecklistTemplate staticWebsite() => _tpl(
        id: 'tpl_static',
        name: 'Static Website Development',
        category: ServiceCategory.staticWebsite,
        description: 'Brochure and marketing websites, from discovery to handover.',
        updatedDaysAgo: 12,
        stages: [
          _discovery(),
          _contract(),
          _s('Planning and Structure', 'Structure, content and brand inputs.', [
            _i('Finalize sitemap and page list', ev: _file, hint: 'Approved sitemap', client: true),
            _i('Collect website content', d: 'Copy, team photos, services, testimonials.', ev: _note, hint: 'Content received', client: true),
            _i('Confirm brand colours and fonts', ev: _note, hint: 'Brand choices', client: true),
            _i('Collect logo and image assets', req: false, client: true),
          ]),
          _s('UI/UX Design', 'Layouts and visual design.', [
            _i('Design homepage', ev: _file, hint: 'Homepage mockup'),
            _i('Get homepage design approval', ev: _note, hint: 'Approval message', client: true),
            _i('Design inner pages', ev: _file, hint: 'Inner page mockups'),
            _i('Get inner page design approval', ev: _note, hint: 'Approval message', client: true),
          ]),
          _s('Website Development', 'Build, make responsive and test.', [
            _i('Build homepage and shared components'),
            _i('Complete responsive development', d: 'Check on phone, tablet and desktop.', ev: _url, hint: 'Staging URL'),
            _i('Test contact forms', ev: _note, hint: 'Test submission result'),
            _i('Optimise images and page speed', req: false),
          ]),
          _s('On-page SEO', 'Make the site easy for search engines to understand.', [
            _i('Write page titles and meta descriptions'),
            _i('Configure basic SEO', d: 'Headings, alt text, canonical tags, robots.txt.', ev: _note, hint: 'SEO checklist done'),
            _i('Add schema markup', req: false),
          ]),
          _s('Domain, Hosting and Deployment', 'Put the site online.', [
            _i('Confirm domain ownership', ev: _note, hint: 'Registrar details', client: true),
            _i('Connect domain and hosting', ev: _url, hint: 'Live site URL'),
            _i('Configure HTTPS', ev: _note, hint: 'SSL check result'),
            _i('Set up business email', req: false, client: true),
          ]),
          _s('Google Setup', 'Search and analytics accounts.', [
            _i('Create Google Analytics property', ev: _note, hint: 'Measurement ID'),
            _i('Verify Google Search Console', ev: _url, hint: 'Search Console URL'),
            _i('Submit sitemap', ev: _note, hint: 'Submission confirmation'),
            _i('Test analytics', ev: _note, hint: 'Real-time report check'),
            _i('Set up Google Business Profile', req: false, client: true),
          ]),
          _s('QA and Go-live', 'Final checks and launch.', [
            _i('Cross-browser and device testing', ev: _note, hint: 'Test results'),
            _i('Final content proofreading', client: true),
            _i('Obtain written client approval', d: 'Email or signed note approving go-live.', ev: _file, hint: 'Client approval', client: true),
            _i('Go live', ev: _url, hint: 'Live website URL'),
          ]),
          _closure(extra: [_i('Transfer credentials', d: 'Hosting, domain and CMS logins.', ev: _note, hint: 'Credentials transferred', client: true)]),
        ],
      );

  static ChecklistTemplate ecommerce() => _tpl(
        id: 'tpl_ecom',
        name: 'Ecommerce / Dynamic Website',
        category: ServiceCategory.ecommerce,
        description: 'Online stores and database-driven websites with payments.',
        updatedDaysAgo: 20,
        stages: [
          _discovery(extra: [_i('Confirm ecommerce platform', ev: _note, hint: 'Platform decision')]),
          _contract(),
          _s('Business Requirements and Planning', 'What is sold, how it ships and what the rules are.', [
            _i('Collect product catalogue', ev: _file, hint: 'Catalogue sheet', client: true),
            _i('Define shipping rules', ev: _note, hint: 'Shipping rules', client: true),
            _i('Collect return and refund policy', ev: _file, hint: 'Policy document', client: true),
            _i('Confirm tax requirements', ev: _note, hint: 'Tax setup notes', client: true),
          ]),
          _s('UI/UX Design', 'Shopping experience and visual design.', [
            _i('Design customer journey', ev: _file, hint: 'Journey map'),
            _i('Design product, cart and checkout pages', ev: _file, hint: 'Page mockups'),
            _i('Get design approval', ev: _note, hint: 'Approval message', client: true),
          ]),
          _s('Website Development', 'Build the store.', [
            _i('Prepare product and order data structure', ev: _note, hint: 'Data model notes'),
            _i('Build catalogue and product pages'),
            _i('Build cart and checkout', ev: _url, hint: 'Staging URL'),
            _i('Configure payment webhooks', ev: _note, hint: 'Webhook test result'),
          ]),
          _s('Payment Gateway and Compliance', 'Take real payments safely.', [
            _i('Finalize payment gateway', ev: _note, hint: 'Gateway chosen', client: true),
            _i('Test payment transactions', ev: _note, hint: 'Test payment results'),
            _i('Obtain live payment gateway approval', ev: _file, hint: 'Gateway approval email', client: true),
            _i('Publish legal pages', d: 'Terms, privacy, shipping and refund pages.', ev: _url, hint: 'Policy page URL'),
          ]),
          _s('On-page SEO', 'Page-level search basics.', [
            _i('Write titles and meta descriptions'),
            _i('Configure clean URL structure', ev: _note, hint: 'URL structure'),
          ]),
          _s('Store SEO', 'Search optimisation specific to products.', [
            _i('Configure store SEO', ev: _note, hint: 'Store SEO checklist'),
            _i('Add product schema markup', ev: _note, hint: 'Rich result test'),
            _i('Write category descriptions', req: false, client: true),
          ]),
          _s('Hosting and Deployment', 'Production environment.', [
            _i('Set up hosting and HTTPS', ev: _url, hint: 'Live URL'),
            _i('Verify backups', d: 'Run a restore test, not just a backup.', ev: _note, hint: 'Backup confirmation'),
            _i('Configure transactional emails', ev: _note, hint: 'Order email test'),
          ]),
          _s('Google Setup and Tracking', 'Measure what matters.', [
            _i('Configure tracking', ev: _note, hint: 'Tracking setup notes'),
            _i('Verify Search Console and submit sitemap', ev: _url, hint: 'Search Console URL'),
            _i('Configure purchase conversion events', ev: _note, hint: 'Event test result'),
            _i('Connect Merchant Center', req: false, client: true),
          ]),
          _s('QA and Store Launch', 'Test every step a customer takes, then launch.', [
            _i('Test complete purchase journey', ev: _note, hint: 'End-to-end test result'),
            _i('Test refunds and order emails', ev: _note, hint: 'Refund test result'),
            _i('Obtain launch approval', ev: _file, hint: 'Launch approval', client: true),
            _i('Launch store', ev: _url, hint: 'Live store URL'),
          ]),
          _s('Operations Handover', 'Make sure the client can run the store.', [
            _i('Prepare operations handover', ev: _file, hint: 'Operations guide'),
            _i('Train client on order management', ev: _note, hint: 'Training notes', client: true),
            _i('Transfer admin credentials', ev: _note, hint: 'Credentials transferred', client: true),
          ]),
          _s('Closure', 'Wrap up.', [
            _i('Verify final payment', ev: _note, hint: 'Payment confirmation'),
            _i('Request testimonial', req: false, client: true),
            _i('Close project and archive files'),
          ]),
        ],
      );

  static ChecklistTemplate crm() => _tpl(
        id: 'tpl_crm',
        name: 'CRM and Automation Development',
        category: ServiceCategory.crm,
        description: 'Custom CRMs and internal business tools with roles, data and reports.',
        updatedDaysAgo: 31,
        stages: [
          _discovery(),
          _contract(),
          _s('Process Mapping', 'Understand how the business works today.', [
            _i('Identify user roles and permissions', ev: _note, hint: 'Roles matrix', client: true),
            _i('Map existing business workflows', ev: _file, hint: 'Workflow map'),
            _i('Collect required fields and sample data', ev: _file, hint: 'Sample data', client: true),
          ]),
          _s('UI/UX and Architecture', 'Design the system before building it.', [
            _i('Get architecture approval', ev: _file, hint: 'Architecture document', client: true),
            _i('Design key screens', ev: _file, hint: 'Screen designs'),
            _i('Get UI approval', ev: _note, hint: 'Approval message', client: true),
          ]),
          _s('Development', 'Build the system.', [
            _i('Complete core modules', ev: _url, hint: 'Staging URL'),
            _i('Configure integrations', ev: _note, hint: 'Integration test result'),
            _i('Build reports and dashboards', req: false),
          ]),
          _s('Data Migration', 'Move existing data across.', [
            _i('Prepare migration scripts'),
            _i('Test data migration', ev: _note, hint: 'Migration test result'),
            _i('Client verifies migrated data', ev: _note, hint: 'Verification message', client: true),
          ]),
          _s('Testing and UAT', 'Prove it works, with the client.', [
            _i('Verify role permissions', ev: _note, hint: 'Permission test result'),
            _i('Complete user acceptance testing', ev: _note, hint: 'UAT results', client: true),
            _i('Obtain UAT approval', ev: _file, hint: 'UAT sign-off', client: true),
          ]),
          _s('Deployment', 'Go live.', [
            _i('Deploy application', ev: _url, hint: 'Production URL'),
            _i('Verify backups and monitoring', ev: _note, hint: 'Backup confirmation'),
          ]),
          _s('Training and Handover', 'Get the team using it.', [
            _i('Conduct user training', ev: _note, hint: 'Training notes', client: true),
            _i('Prepare user guide', ev: _file, hint: 'User guide'),
          ]),
          _s('Hypercare', 'Extra support straight after launch.', [
            _i('Monitor issues during hypercare', ev: _note, hint: 'Issue log'),
            _i('Complete hypercare period', ev: _note, hint: 'Hypercare summary'),
          ]),
          _s('Closure', 'Wrap up.', [
            _i('Complete final handover', ev: _file, hint: 'Handover document', client: true),
            _i('Verify final payment', ev: _note, hint: 'Payment confirmation'),
            _i('Request testimonial', req: false, client: true),
          ]),
        ],
      );

  static ChecklistTemplate mobileApp() => _tpl(
        id: 'tpl_mobile',
        name: 'Mobile Application Development',
        category: ServiceCategory.mobileApp,
        description: 'Android and iOS apps from product definition to store launch.',
        updatedDaysAgo: 8,
        stages: [
          _discovery(extra: [_i('Collect application requirements', ev: _note, hint: 'Requirements summary', client: true)]),
          _contract(),
          _s('Product Definition', 'What the app does and for whom.', [
            _i('Define user flows', ev: _file, hint: 'User flow diagram'),
            _i('Agree the MVP feature list', ev: _note, hint: 'Agreed features', client: true),
          ]),
          _s('Architecture and UI/UX Design', 'Technical plan and screens.', [
            _i('Finalize application architecture', ev: _file, hint: 'Architecture notes'),
            _i('Obtain design approval', ev: _file, hint: 'Design approval', client: true),
            _i('Prepare design handoff assets', req: false),
          ]),
          _s('Development', 'Build the app.', [
            _i('Complete application development', ev: _url, hint: 'Test build link'),
            _i('Integrate backend APIs', ev: _note, hint: 'API test result'),
            _i('Add analytics and crash reporting', req: false),
          ]),
          _s('QA and Release Readiness', 'Test and prepare for the stores.', [
            _i('Perform QA testing', ev: _file, hint: 'QA report'),
            _i('Complete client acceptance testing', ev: _note, hint: 'Acceptance message', client: true),
            _i('Prepare store listings', ev: _file, hint: 'Store listing content', client: true),
            _i('Verify release readiness', ev: _note, hint: 'Release checklist'),
          ]),
          _s('Launch', 'Publish the app.', [
            _i('Submit to app stores', ev: _url, hint: 'Store console link'),
            _i('Launch application', ev: _url, hint: 'Store listing URL'),
          ]),
          _s('Post-launch', 'Watch how it behaves in the real world.', [
            _i('Monitor application after launch', ev: _note, hint: 'Monitoring notes'),
            _i('Fix launch issues', req: false),
          ]),
          _s('Handover and Closure', 'Hand over code and ownership.', [
            _i('Verify final payment', ev: _note, hint: 'Payment confirmation'),
            _i('Complete code and ownership handover', ev: _file, hint: 'Handover document', client: true),
            _i('Request testimonial', req: false, client: true),
          ]),
        ],
      );

  static ChecklistTemplate workflow() => _tpl(
        id: 'tpl_workflow',
        name: 'Workflow Automation',
        category: ServiceCategory.workflow,
        description: 'Automating manual processes across tools and systems.',
        updatedDaysAgo: 45,
        stages: [
          _s('Discovery and Process Mapping', 'Understand the manual process end to end.', [
            _i('Document current manual process', ev: _file, hint: 'Process document', client: true),
            _i('Identify triggers and actions', ev: _note, hint: 'Triggers and actions'),
            _i('Identify connected systems', ev: _note, hint: 'System list', client: true),
            _i('Confirm API access availability', ev: _note, hint: 'Access confirmation', client: true),
          ]),
          _contract(),
          _s('Workflow Design', 'Design before building.', [
            _i('Prepare workflow diagram', ev: _file, hint: 'Workflow diagram'),
            _i('Define error handling rules', ev: _note, hint: 'Error handling rules'),
            _i('Get workflow design approval', ev: _note, hint: 'Approval message', client: true),
          ]),
          _s('Integration and Development', 'Build and connect.', [
            _i('Build workflow', ev: _url, hint: 'Workflow link'),
            _i('Configure error handling', ev: _note, hint: 'Error handling test'),
            _i('Configure failure alerts', ev: _note, hint: 'Alert channel'),
          ]),
          _s('Testing', 'Break it before real data does.', [
            _i('Test failure alerts', ev: _note, hint: 'Alert test result'),
            _i('Test with real-world sample cases', ev: _note, hint: 'Sample case results', client: true),
            _i('Fix issues found', req: false),
          ]),
          _s('Deployment and Monitoring', 'Switch on and watch.', [
            _i('Deploy to production', ev: _note, hint: 'Deployment confirmation'),
            _i('Conduct client walkthrough', ev: _note, hint: 'Walkthrough notes', client: true),
            _i('Complete monitoring period', ev: _note, hint: 'Monitoring summary'),
          ]),
          _closure(),
        ],
      );

  static ChecklistTemplate maintenance() => _tpl(
        id: 'tpl_maint',
        name: 'Monthly Support and Maintenance',
        category: ServiceCategory.maintenance,
        description: 'Recurring monthly care: health checks, backups, updates and reporting.',
        updatedDaysAgo: 5,
        step: 1,
        stages: [
          _s('Monthly Health Check', 'Is everything up and working?', [
            _i('Check website/application availability', ev: _note, hint: 'Uptime check'),
            _i('Check forms and key user journeys', ev: _note, hint: 'Journey test result'),
            _i('Review speed and error reports', req: false),
          ]),
          _s('Backup and Security', 'Protect the site and the data.', [
            _i('Verify backups', ev: _note, hint: 'Backup confirmation'),
            _i('Scan for malware and vulnerabilities', ev: _note, hint: 'Scan result'),
            _i('Review user accounts and access', req: false),
          ]),
          _s('Updates and Maintenance', 'Keep software current.', [
            _i('Apply required updates', ev: _note, hint: 'Update log'),
            _i('Test the site after updates', ev: _note, hint: 'Post-update check'),
            _i('Clean up logs and database', req: false),
          ]),
          _s('Client Requests', 'Small changes the client asks for.', [
            _i('Log minor change requests', ev: _note, hint: 'Request log'),
            _i('Complete requested changes', client: true),
            _i('Update client on pending requests', req: false, client: true),
          ]),
          _s('Monthly Reporting', 'Show the value of the plan.', [
            _i('Prepare monthly report', ev: _file, hint: 'Monthly report'),
            _i('Send report to client', ev: _note, hint: 'Sent confirmation', client: true),
          ]),
          _s('Renewal Management', 'Nothing should expire by surprise.', [
            _i('Check domain renewal date', ev: _note, hint: 'Renewal date'),
            _i('Check hosting renewal date', ev: _note, hint: 'Renewal date'),
            _i('Flag renewals due within 60 days', d: 'Tell the client early and quote the renewal.', ev: _note, hint: 'Client informed'),
          ]),
        ],
      );
}
