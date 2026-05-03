export const mockHistory = [
  {
    id: 'AR-2025-001',
    collectedAt: 'Nov 18, 2025',
    type: 'Complete Blood Count',
    status: 'Hemoglobin flagged as low. Monitor symptoms if needed.',
    impression: 'Slight anemia detected. Stay hydrated and discuss iron intake with your clinician.',
    highlights: [
      { label: 'Hemoglobin', value: '11.2 g/dL', state: 'Low', note: 'Below the recommended range for adults.' },
      { label: 'WBC', value: '5.2 K/µL', state: 'Normal', note: 'Immune response is within the expected range.' },
      { label: 'Platelets', value: '230 K/µL', state: 'Normal', note: 'Platelet count remains stable.' },
    ],
  },
  {
    id: 'AR-2025-002',
    collectedAt: 'Oct 02, 2025',
    type: 'Metabolic Panel',
    status: 'ALT slightly elevated. Review with your care provider.',
    impression: 'Liver enzymes rose above baseline, so hydration and rest were recommended.',
    highlights: [
      { label: 'ALT', value: '78 U/L', state: 'High', note: 'Above reference range; retest if symptoms persist.' },
      { label: 'AST', value: '32 U/L', state: 'Normal', note: 'No concerns detected.' },
      { label: 'Glucose', value: '92 mg/dL', state: 'Normal', note: 'Fasting glucose remains steady.' },
    ],
  },
  {
    id: 'AR-2025-003',
    collectedAt: 'Aug 24, 2025',
    type: 'A1C & Lipids',
    status: 'A1C stable. HDL slightly low.',
    impression: 'Overall metabolic control is stable with a reminder to support healthy HDL levels.',
    highlights: [
      { label: 'A1C', value: '5.7%', state: 'Normal', note: 'Consistent with previous test.' },
      { label: 'HDL', value: '38 mg/dL', state: 'Low', note: 'Encourage more activity and omega-rich foods.' },
      { label: 'LDL', value: '84 mg/dL', state: 'Normal', note: 'LDL remained within goal range.' },
    ],
  },
]
