# Decentralized Community Land Trust Management System

A blockchain-based system for managing community land trusts and affordable housing using Stacks blockchain and Clarity smart contracts.

## Overview

This system provides a decentralized framework for Community Land Trusts (CLTs) to manage affordable housing, ensure long-term affordability, and enable community governance. The system consists of five interconnected smart contracts that handle different aspects of CLT operations.

## System Architecture

### Core Contracts

1. **Land Ownership Verification Contract** (`land-ownership.clar`)
    - Manages land trust ownership records
    - Verifies land is held in perpetual trust
    - Tracks land parcel details and restrictions

2. **Housing Affordability Restriction Contract** (`affordability-restrictions.clar`)
    - Enforces resale price limitations
    - Calculates maximum allowable sale prices
    - Maintains affordability for future residents

3. **Community Member Selection Contract** (`member-selection.clar`)
    - Manages resident application and selection process
    - Prioritizes local residents and essential workers
    - Handles waitlist and eligibility verification

4. **Property Maintenance Coordination Contract** (`maintenance-coordination.clar`)
    - Coordinates property maintenance and repairs
    - Manages maintenance funds and contractor selection
    - Tracks maintenance history and schedules

5. **Resident Participation Governance Contract** (`governance.clar`)
    - Enables resident voting on CLT decisions
    - Manages proposals and voting processes
    - Ensures democratic participation in community decisions

## Key Features

- **Perpetual Affordability**: Ensures housing remains affordable across generations
- **Community Control**: Residents have voting power in CLT operations
- **Transparent Selection**: Fair and transparent resident selection process
- **Maintenance Coordination**: Systematic approach to property upkeep
- **Land Trust Verification**: Blockchain-verified land ownership in trust

## Data Structures

### Land Parcel
- Parcel ID
- Location coordinates
- Size and zoning information
- Trust establishment date
- Current restrictions

### Housing Unit
- Unit ID
- Parcel reference
- Current resident
- Purchase price and date
- Affordability restrictions

### Community Member
- Member address
- Application date
- Priority score
- Essential worker status
- Local residency verification

### Maintenance Request
- Request ID
- Property reference
- Issue description
- Priority level
- Assigned contractor
- Completion status

## Getting Started

### Prerequisites
- Clarinet CLI
- Node.js and npm
- Stacks wallet for testing

### Installation

1. Clone the repository
2. Install dependencies:
   \`\`\`bash
   npm install
   \`\`\`

3. Run tests:
   \`\`\`bash
   npm test
   \`\`\`

4. Deploy contracts:
   \`\`\`bash
   clarinet deploy
   \`\`\`

## Usage

### For CLT Administrators
1. Initialize land trust with verified parcels
2. Set affordability restrictions and formulas
3. Configure member selection criteria
4. Establish maintenance coordination processes
5. Set up governance voting parameters

### For Community Members
1. Apply for housing through member selection contract
2. Participate in governance voting
3. Submit maintenance requests
4. Transfer housing units within affordability restrictions

### For Essential Workers
1. Receive priority in member selection
2. Access special affordability programs
3. Participate in community governance

## Testing

The system includes comprehensive tests for all contracts:

- Unit tests for individual contract functions
- Integration tests for cross-contract interactions
- Governance scenario testing
- Affordability calculation verification
- Member selection process validation

Run tests with:
\`\`\`bash
npm test
\`\`\`

## Security Considerations

- All contracts include proper access controls
- Financial calculations use safe arithmetic
- Governance processes prevent manipulation
- Member data is properly protected
- Maintenance funds are securely managed

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions or support, please open an issue in the repository or contact the development team.
