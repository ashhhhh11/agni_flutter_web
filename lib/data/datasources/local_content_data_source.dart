
import '../../domain/entities/agni_content.dart';

class LocalContentDataSource {
  AgniContent load() {
    const navItems = [''];

    const marqueeItems = [
      'Wipro', 'Lumen', 'Modivcare', 'Quest', 'Carter Bank & Trust',
      'Econet', 'Ethio Telecom', 'LTIMindtree', 'Tiger Analytics', 'Nextuple',
    ];

    const heroLangs = [
      'Agentic AI', 'RPA', 'Data & Analytics', 'QA', 'Super Apps',
      'Cloud', 'Automation', 'Digital', 'Telecom', 'Banking'
    ];

    const tickerTags = [
      'Banking', 'Telecom', 'Healthcare', 'Insurance', 'Retail',
    ];

    const stats = [
      StatItem('2020', 'Founded in Bangalore, India'),
      StatItem('30+ clients', 'Across USA, India, Europe, MENA, Africa'),
      StatItem('650+    automations', 'Delivered with RPA and agentic AI'),
      StatItem('10x ROI', 'Year-one ROI achieved for banking clients'),
    ];

    const features = [
      FeatureItem(
        '🤖',
        'Agentic AI',
        'Autonomous workflows, predictive insights, and conversational copilots for growth.',
        'KYC · Marketing · Support · Collections',
      ),
      FeatureItem(
        '🦾',
        'Robotic Process Automation',
        'Eliminate repetitive work with fast, error-free automations for ops and finance.',
        '200+ processes automated',
      ),
      FeatureItem(
        '📊',
        'Data & Analytics',
        'Modern data pipelines, ML models, and dashboards that turn raw data into clear decisions.',
        '95% accuracy · real-time insights',
      ),
      FeatureItem(
        '🧪',
        'Automation Testing',
        'Manual and automated QA across web, mobile, APIs with performance and security.',
        'CI/CD ready · reliable releases',
      ),
      FeatureItem(
        '🛠️',
        'Custom Development',
        'Cloud-ready apps, APIs, and integrations tailored to each business.',
        'Secure · scalable · bespoke',
      ),
      FeatureItem(
        '🌐',
        'Super App Development',
        'Unified digital ecosystems that bring multiple services into one seamless experience.',
        'Omnichannel · loyalty · growth',
      ),
    ];

    const comparisons = [
      ComparisonCardData(
        isOurs: false,
        badge: 'Traditional landscape',
        headline: 'Slow delivery. One-size-fits-all. Limited AI expertise.',
        items: [
          'Long discovery and fixed playbooks',
          'Minimal automation or agentic AI depth',
          'High cost, low speed to value',
          'Limited domain coverage across regions',
          'Siloed teams and handoffs',
        ],
      ),
      ComparisonCardData(
        isOurs: true,
        badge: 'Technodysis',
        headline: 'Agentic AI + automation built for Healthcare, Banking, Insurance, Telecom, Retail.',
        items: [
          'Domain-first accelerators and reusable workflows',
          'Agentic AI + RPA to 10x ROI in year one',
          'Global delivery from Bangalore, Austin, London, Dubai',
          'Security, compliance, and quality baked in',
          'Co-creation with your teams for faster adoption',
        ],
      ),
    ];

    const langPills = [
      LangPill('Healthcare', 'ocean'), LangPill('Banking', 'ocean'), LangPill('Insurance', 'forest'),
      LangPill('Telecom', ''), LangPill('Retail', ''), LangPill('Agentic AI', ''),
      LangPill('RPA', 'ocean'), LangPill('Data & Analytics', ''), LangPill('Testing', ''),
      LangPill('Custom Dev', ''), LangPill('Super Apps', ''), LangPill('Cloud', ''),
      LangPill('USA', 'forest'), LangPill('India', 'forest'), LangPill('UK', 'forest'),
      LangPill('Africa', 'ocean'),
      LangPill('Austin', ''),
      LangPill('ME', 'ocean'),
      LangPill('+ more', ''),
    ];

    const floatingCards = [
      // FloatingCardData('650+ automations', 'Delivered', 1.0),
      FloatingCardData('10x ROI', 'Year-one banking ROI', 2.2),
    ];

    return AgniContent(
      navItems: navItems,
      marqueeItems: marqueeItems,
      heroLangs: heroLangs,
      tickerTags: tickerTags,
      stats: stats,
      features: features,
      comparisons: comparisons,
      langPills: langPills,
      floatingCards: floatingCards,
    );
  }
}
