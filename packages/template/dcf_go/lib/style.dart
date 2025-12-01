// Style and layout registries for DotCorr Landing Page
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' show Colors;

final styles = DCFStyleSheet.create({
  'root': DCFStyleSheet(
    backgroundColor: Colors.white,
  ),
  // Navigation
  'nav': DCFStyleSheet(
    backgroundColor: Colors.white,
  ),
  'navLogoText': DCFStyleSheet(
    primaryColor: Colors.black,
  ),
  'navLink': DCFStyleSheet(
    primaryColor: Colors.grey,
  ),
  // Hero
  'hero': DCFStyleSheet(
    backgroundColor: Colors.white,
  ),
  'heroTitle': DCFStyleSheet(
    primaryColor: Colors.black,
  ),
  'heroButton': DCFStyleSheet(
    backgroundColor: Colors.black,
    borderRadius: 4,
  ),
  'heroButtonText': DCFStyleSheet(
    primaryColor: Colors.white,
  ),
  'typewriterText': DCFStyleSheet(
    primaryColor: Colors.grey[600]!,
  ),
  'ecosystemLabel': DCFStyleSheet(
    primaryColor: Colors.grey[400]!,
  ),
  'ecosystemLogo': DCFStyleSheet(
    primaryColor: Colors.grey,
  ),
  // Sections
  'section': DCFStyleSheet(
    backgroundColor: Colors.white,
  ),
  'sectionGray': DCFStyleSheet(
    backgroundColor: Colors.grey[50]!,
  ),
  'sectionDark': DCFStyleSheet(
    backgroundColor: Colors.grey[900]!,
  ),
  'sectionTitle': DCFStyleSheet(
    primaryColor: Colors.black,
  ),
  'sectionDescription': DCFStyleSheet(
    primaryColor: Colors.grey[500]!,
  ),
  // Cards
  'cardWhite': DCFStyleSheet(
    backgroundColor: Colors.white,
    borderRadius: 0,
    borderWidth: 1,
    borderColor: Colors.grey[200]!,
  ),
  'cardBlack': DCFStyleSheet(
    backgroundColor: Colors.black,
    borderRadius: 0,
  ),
  'cardTitle': DCFStyleSheet(
    primaryColor: Colors.black,
  ),
  'cardTitleWhite': DCFStyleSheet(
    primaryColor: Colors.white,
  ),
  'cardDescription': DCFStyleSheet(
    primaryColor: Colors.grey[500]!,
  ),
  'cardDescriptionWhite': DCFStyleSheet(
    primaryColor: Colors.grey[300]!,
  ),
  // Features
  'featureCard': DCFStyleSheet(
    backgroundColor: Colors.white,
    borderRadius: 0,
  ),
  'featureTitle': DCFStyleSheet(
    primaryColor: Colors.black,
  ),
  'featureDescription': DCFStyleSheet(
    primaryColor: Colors.grey[500]!,
  ),
  // About
  'aboutLabel': DCFStyleSheet(
    primaryColor: Colors.white,
  ),
  'aboutTitle': DCFStyleSheet(
    primaryColor: Colors.white,
  ),
  'aboutDescription': DCFStyleSheet(
    primaryColor: Colors.grey[300]!,
  ),
  'aboutInfoText': DCFStyleSheet(
    primaryColor: Colors.grey[400]!,
  ),
  // Footer
  'footer': DCFStyleSheet(
    backgroundColor: Colors.white,
    borderWidth: 1,
    borderColor: Colors.grey[200]!,
  ),
  'footerBrandText': DCFStyleSheet(
    primaryColor: Colors.black,
  ),
  'footerDescription': DCFStyleSheet(
    primaryColor: Colors.grey[500]!,
  ),
  'footerLink': DCFStyleSheet(
    primaryColor: Colors.grey[500]!,
  ),
  'footerCopyright': DCFStyleSheet(
    primaryColor: Colors.grey[500]!,
  ),
});

final layouts = DCFLayout.create({
  'root': DCFLayout(
    flex: 1,
    width: '100%',
    height: '100%',
  ),
  // Navigation
  'nav': DCFLayout(
    width: '100%',
    height: 64,
    paddingHorizontal: 24,
    // Removed absolute positioning so it's in normal flow and visible
  ),
  'navContainer': DCFLayout(
    width: '100%',
    maxWidth: 1280,
    flexDirection: DCFFlexDirection.row,
    alignItems: DCFAlign.center,
    justifyContent: DCFJustifyContent.spaceBetween,
  ),
  'navLogo': DCFLayout(
    flexDirection: DCFFlexDirection.row,
    alignItems: DCFAlign.center,
    gap: 8,
  ),
  'navLinks': DCFLayout(
    flexDirection: DCFFlexDirection.row,
    alignItems: DCFAlign.center,
    gap: 24,
  ),
  // Hero
  'hero': DCFLayout(
    width: '100%',
    paddingTop: 128,
    paddingBottom: 80,
    paddingHorizontal: 24,
    minHeight: '90vh',
  ),
  'heroContainer': DCFLayout(
    width: '100%',
    maxWidth: 1280,
    flexDirection: DCFFlexDirection.row,
    gap: 64,
    marginBottom: 80,
  ),
  'heroLeft': DCFLayout(
    flex: 1,
    gap: 32,
  ),
  'heroRight': DCFLayout(
    flex: 1,
    height: 600,
    alignItems: DCFAlign.center,
    justifyContent: DCFJustifyContent.center,
  ),
  'heroButton': DCFLayout(
    paddingHorizontal: 32,
    paddingVertical: 16,
    flexDirection: DCFFlexDirection.row,
    alignItems: DCFAlign.center,
    gap: 12,
  ),
  'typewriter': DCFLayout(
    height: 80,
    alignItems: DCFAlign.center,
    justifyContent: DCFJustifyContent.center,
  ),
  'ecosystem': DCFLayout(
    width: '100%',
    paddingTop: 48,
    gap: 32,
  ),
  'ecosystemLogos': DCFLayout(
    flexDirection: DCFFlexDirection.row,
    flexWrap: DCFWrap.wrap,
    gap: 48,
    alignItems: DCFAlign.center,
  ),
  // Infrastructure Visual
  'infraContainer': DCFLayout(
    width: '100%',
    height: '100%',
    position: DCFPositionType.relative,
    alignItems: DCFAlign.center,
    justifyContent: DCFJustifyContent.center,
  ),
  // Sections
  'section': DCFLayout(
    width: '100%',
    paddingVertical: 96,
    paddingHorizontal: 48,
  ),
  'sectionHeader': DCFLayout(
    width: '100%',
    marginBottom: 80,
    gap: 24,
  ),
  'cardsGrid': DCFLayout(
    width: '100%',
    flexDirection: DCFFlexDirection.row,
    gap: 32,
  ),
  'card': DCFLayout(
    flex: 1,
    padding: 40,
    gap: 24,
  ),
  'featuresGrid': DCFLayout(
    width: '100%',
    flexDirection: DCFFlexDirection.row,
    flexWrap: DCFWrap.wrap,
  ),
  'featureCard': DCFLayout(
    flex: 1,
    minWidth: '25%',
    padding: 40,
    gap: 24,
  ),
  'aboutContainer': DCFLayout(
    width: '100%',
    maxWidth: 1024,
    alignItems: DCFAlign.center,
    gap: 48,
  ),
  'aboutInfo': DCFLayout(
    width: '100%',
    maxWidth: 768,
    flexDirection: DCFFlexDirection.row,
    flexWrap: DCFWrap.wrap,
    gap: 32,
    paddingTop: 32,
  ),
  // Footer
  'footer': DCFLayout(
    width: '100%',
    paddingTop: 64,
    paddingBottom: 48,
    paddingHorizontal: 48,
    gap: 64,
  ),
  'footerContainer': DCFLayout(
    width: '100%',
    maxWidth: 1280,
    flexDirection: DCFFlexDirection.row,
    flexWrap: DCFWrap.wrap,
    gap: 48,
    marginBottom: 64,
  ),
  'footerBrand': DCFLayout(
    flex: 2,
    gap: 24,
  ),
  'footerLinks': DCFLayout(
    flex: 1,
    gap: 12,
  ),
  'footerBottom': DCFLayout(
    width: '100%',
    paddingTop: 32,
    flexDirection: DCFFlexDirection.row,
    justifyContent: DCFJustifyContent.spaceBetween,
  ),
});
