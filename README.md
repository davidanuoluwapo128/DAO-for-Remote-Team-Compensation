# 🏛️ DAO for Remote Team Compensation

> A decentralized autonomous organization (DAO) smart contract for managing transparent and fair compensation for remote teams using the Stacks blockchain.

## 🎯 Overview

This smart contract enables remote teams to manage compensation through a decentralized, transparent, and trustless system. Team members can submit tasks, vote on approvals, and receive automated payments directly from the DAO treasury.

## ✨ Features

### 🏦 Treasury Management
- **Secure fund storage** with automated disbursements
- **Emergency controls** for contract owner
- **Real-time balance tracking**

### 📋 Task Management
- **Task submission** with detailed metadata (type, duration, complexity)
- **Structured voting process** with customizable approval thresholds
- **Automated payment execution** upon approval

### 🗳️ Governance
- **Member-based voting** with configurable voting power
- **Transparent approval process** with on-chain vote tracking
- **Deadline-based voting periods**

### 📊 Contribution Tracking
- **Complete work history** for each member
- **Reputation scoring** based on completed tasks and ratings
- **Earnings transparency** with total compensation tracking

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Stacks wallet for testing

### Installation
```bash
git clone <repository-url>
cd DAO-for-Remote-Team-Compensation
clarinet check
```

### Testing
```bash
npm install
npm test
```

## 📖 Usage Guide

### 1. 🏗️ Initialize the DAO
```clarity
(contract-call? .DAO-for-Remote-Team-Compensation initialize-dao)
```

### 2. 👥 Add Team Members
```clarity
(contract-call? .DAO-for-Remote-Team-Compensation add-member 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u50)
```

### 3. 💰 Fund the Treasury
```clarity
(contract-call? .DAO-for-Remote-Team-Compensation deposit-to-treasury u1000000)
```

### 4. 📝 Submit a Task
```clarity
(contract-call? .DAO-for-Remote-Team-Compensation submit-task 
    "Frontend Development" 
    "Build user dashboard with wallet integration" 
    u500000
    "Development" 
    u168
    u8
    u1008)
```

### 5. 🗳️ Vote on Tasks
```clarity
(contract-call? .DAO-for-Remote-Team-Compensation vote-on-task u1 true)
```

### 6. ⚡ Execute Approved Tasks
```clarity
(contract-call? .DAO-for-Remote-Team-Compensation execute-task u1)
```

## 🔧 Contract Functions

### 📊 Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `initialize-dao` | Initialize the DAO | None |
| `add-member` | Add new team member | `member`, `voting-power` |
| `remove-member` | Deactivate member | `member` |
| `deposit-to-treasury` | Add funds to treasury | `amount` |
| `submit-task` | Create new task | `title`, `description`, `compensation`, `task-type`, `duration`, `complexity`, `voting-duration` |
| `vote-on-task` | Vote on task approval | `task-id`, `vote` |
| `execute-task` | Process approved task payment | `task-id` |
| `update-minimum-approval` | Change approval threshold | `new-percentage` |
| `emergency-withdraw` | Owner emergency fund withdrawal | `amount` |

### 📖 Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-member` | Member details | Member data |
| `get-task` | Task details | Task data |
| `get-treasury-balance` | Current treasury funds | Balance amount |
| `get-voting-status` | Task voting information | Vote counts and status |
| `is-task-approved` | Check if task meets approval threshold | Boolean |
| `calculate-member-reputation` | Member reputation score | Reputation value |

## 🏗️ Data Structures

### 👤 Member
```clarity
{
    voting-power: uint,
    joined-at: uint,
    total-earnings: uint,
    is-active: bool
}
```

### 📋 Task
```clarity
{
    creator: principal,
    title: string-ascii,
    description: string-ascii,
    compensation: uint,
    task-type: string-ascii,
    duration: uint,
    complexity: uint,
    created-at: uint,
    voting-deadline: uint,
    is-executed: bool,
    yes-votes: uint,
    no-votes: uint
}
```

## ⚙️ Configuration

- **Default minimum approval**: 60%
- **Voting power range**: 1-100
- **Task complexity scale**: 1-10
- **Duration**: Hours (uint)

## 🛡️ Security Features

- ✅ **Authorization checks** for admin functions
- ✅ **Double-voting prevention**
- ✅ **Deadline enforcement**
- ✅ **Balance validation**
- ✅ **Emergency controls**

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Guide](https://docs.hiro.so/stacks/clarinet)

---

Built with ❤️ for the future of remote work on Stacks blockchain
