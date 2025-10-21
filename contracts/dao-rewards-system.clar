;; DAO for Remote Team Compensation with Advanced Rewards System
;; A comprehensive DAO system for managing remote team compensation with automated rewards distribution

;; Constants
(define-constant contract-owner tx-sender)

;; Error constants
(define-constant err-not-authorized (err u100))
(define-constant err-not-member (err u101))
(define-constant err-task-not-found (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-voting-closed (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-task-already-executed (err u107))
(define-constant err-minimum-approval-not-met (err u108))
(define-constant err-rewards-already-distributed (err u109))
(define-constant err-invalid-reward-period (err u110))
(define-constant err-no-eligible-members (err u111))
(define-constant err-reward-pool-insufficient (err u112))
(define-constant err-invalid-contribution-score (err u113))

;; System constants
(define-constant default-voting-period u1008)
(define-constant execution-delay u144)
(define-constant reward-distribution-interval u1008)
(define-constant minimum-contribution-threshold u50)

;; Tier constants
(define-constant tier-bronze u1)
(define-constant tier-silver u2)
(define-constant tier-gold u3)
(define-constant tier-platinum u4)

;; Milestone constants
(define-constant milestone-bronze-tasks u5)
(define-constant milestone-silver-tasks u15)
(define-constant milestone-gold-tasks u35)
(define-constant milestone-platinum-tasks u75)

(define-constant milestone-bronze-earnings u500)
(define-constant milestone-silver-earnings u2000)
(define-constant milestone-gold-earnings u6000)
(define-constant milestone-platinum-earnings u15000)

;; Data variables
(define-data-var total-members uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var task-counter uint u0)
(define-data-var minimum-approval-percentage uint u60)
(define-data-var reward-pool uint u0)
(define-data-var last-reward-distribution uint u0)
(define-data-var reward-distribution-counter uint u0)
(define-data-var base-reward-amount uint u100)

;; Data maps
(define-map members principal {
    voting-power: uint,
    joined-at: uint,
    total-earnings: uint,
    is-active: bool,
    contribution-score: uint
})

(define-map tasks uint {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    compensation: uint,
    task-type: (string-ascii 50),
    duration: uint,
    complexity: uint,
    created-at: uint,
    voting-deadline: uint,
    is-executed: bool,
    yes-votes: uint,
    no-votes: uint
})

(define-map task-votes {task-id: uint, voter: principal} bool)

(define-map member-contributions principal {
    tasks-completed: uint,
    total-compensation: uint,
    average-rating: uint,
    last-active: uint,
    current-tier: uint
})

(define-map reward-distributions uint {
    distribution-date: uint,
    total-pool: uint,
    eligible-members: uint,
    average-reward: uint,
    total-distributed: uint
})

(define-map member-rewards principal {
    total-rewards-received: uint,
    last-reward-date: uint,
    reward-multiplier: uint,
    lifetime-contribution-score: uint
})

;; Initialize DAO
(define-public (initialize-dao)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (try! (add-member contract-owner u100))
        (var-set treasury-balance u0)
        (var-set reward-pool u0)
        (var-set last-reward-distribution stacks-block-height)
        (ok true)
    )
)

;; Member management
(define-public (add-member (new-member principal) (voting-power uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (> voting-power u0) err-invalid-amount)
        
        (map-set members new-member {
            voting-power: voting-power,
            joined-at: stacks-block-height,
            total-earnings: u0,
            is-active: true,
            contribution-score: u0
        })
        
        (map-set member-contributions new-member {
            tasks-completed: u0,
            total-compensation: u0,
            average-rating: u0,
            last-active: stacks-block-height,
            current-tier: u0
        })
        
        (map-set member-rewards new-member {
            total-rewards-received: u0,
            last-reward-date: u0,
            reward-multiplier: u100,
            lifetime-contribution-score: u0
        })
        
        (var-set total-members (+ (var-get total-members) u1))
        (ok true)
    )
)

(define-public (remove-member (member principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (match (map-get? members member)
            member-data (begin
                (map-set members member (merge member-data {is-active: false}))
                (var-set total-members (- (var-get total-members) u1))
                (ok true)
            )
            err-not-member
        )
    )
)

;; Treasury management
(define-public (deposit-to-treasury (amount uint))
    (begin
        (asserts! (> amount u0) err-invalid-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (ok true)
    )
)

(define-public (fund-reward-pool (amount uint))
    (begin
        (asserts! (is-member tx-sender) err-not-member)
        (asserts! (> amount u0) err-invalid-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set reward-pool (+ (var-get reward-pool) amount))
        (ok true)
    )
)

;; Task management
(define-public (submit-task 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (compensation uint)
    (task-type (string-ascii 50))
    (duration uint)
    (complexity uint)
    (voting-duration uint)
)
    (let (
        (task-id (+ (var-get task-counter) u1))
        (deadline (+ stacks-block-height voting-duration))
        (member-data (unwrap! (map-get? members tx-sender) err-not-member))
    )
        (asserts! (get is-active member-data) err-not-member)
        (asserts! (> compensation u0) err-invalid-amount)
        (asserts! (<= compensation (var-get treasury-balance)) err-insufficient-funds)
        
        (map-set tasks task-id {
            creator: tx-sender,
            title: title,
            description: description,
            compensation: compensation,
            task-type: task-type,
            duration: duration,
            complexity: complexity,
            created-at: stacks-block-height,
            voting-deadline: deadline,
            is-executed: false,
            yes-votes: u0,
            no-votes: u0
        })
        
        (var-set task-counter task-id)
        (ok task-id)
    )
)

(define-public (vote-on-task (task-id uint) (vote bool))
    (let (
        (task-data (unwrap! (map-get? tasks task-id) err-task-not-found))
        (member-data (unwrap! (map-get? members tx-sender) err-not-member))
        (vote-key {task-id: task-id, voter: tx-sender})
    )
        (asserts! (get is-active member-data) err-not-member)
        (asserts! (<= stacks-block-height (get voting-deadline task-data)) err-voting-closed)
        (asserts! (is-none (map-get? task-votes vote-key)) err-already-voted)
        (asserts! (not (get is-executed task-data)) err-task-already-executed)
        
        (map-set task-votes vote-key vote)
        
        (if vote
            (map-set tasks task-id (merge task-data {
                yes-votes: (+ (get yes-votes task-data) (get voting-power member-data))
            }))
            (map-set tasks task-id (merge task-data {
                no-votes: (+ (get no-votes task-data) (get voting-power member-data))
            }))
        )
        (ok true)
    )
)

(define-public (execute-task (task-id uint))
    (let (
        (task-data (unwrap! (map-get? tasks task-id) err-task-not-found))
        (total-votes (+ (get yes-votes task-data) (get no-votes task-data)))
        (approval-rate (if (> total-votes u0) 
            (* (/ (get yes-votes task-data) total-votes) u100) 
            u0))
        (creator (get creator task-data))
        (compensation (get compensation task-data))
        (complexity (get complexity task-data))
    )
        (asserts! (> stacks-block-height (get voting-deadline task-data)) err-voting-closed)
        (asserts! (not (get is-executed task-data)) err-task-already-executed)
        (asserts! (>= approval-rate (var-get minimum-approval-percentage)) err-minimum-approval-not-met)
        (asserts! (>= (var-get treasury-balance) compensation) err-insufficient-funds)
        
        ;; Transfer compensation
        (try! (as-contract (stx-transfer? compensation tx-sender creator)))
        (var-set treasury-balance (- (var-get treasury-balance) compensation))
        
        ;; Update task status
        (map-set tasks task-id (merge task-data {is-executed: true}))
        
        ;; Update member earnings
        (match (map-get? members creator)
            member-data (map-set members creator (merge member-data {
                total-earnings: (+ (get total-earnings member-data) compensation)
            }))
            false
        )
        
        ;; Update member contributions and contribution score
        (try! (update-member-contributions creator compensation complexity))
        (ok true)
    )
)

;; NEW FEATURE: Advanced Rewards Distribution System
(define-public (distribute-periodic-rewards)
    (let (
        (current-height stacks-block-height)
        (last-distribution (var-get last-reward-distribution))
        (distribution-id (+ (var-get reward-distribution-counter) u1))
        (available-pool (var-get reward-pool))
    )
        (asserts! (>= (- current-height last-distribution) reward-distribution-interval) err-invalid-reward-period)
        (asserts! (> available-pool u0) err-reward-pool-insufficient)
        
        (let (
            (eligible-members-list (get-eligible-members-for-rewards))
            (total-eligible (len eligible-members-list))
        )
            (asserts! (> total-eligible u0) err-no-eligible-members)
            
            (let (
                (total-distributed (unwrap! (distribute-rewards-to-members eligible-members-list available-pool) err-reward-pool-insufficient))
            )
                ;; Record distribution
                (map-set reward-distributions distribution-id {
                    distribution-date: current-height,
                    total-pool: available-pool,
                    eligible-members: total-eligible,
                    average-reward: (/ total-distributed total-eligible),
                    total-distributed: total-distributed
                })
                
                ;; Update system state
                (var-set last-reward-distribution current-height)
                (var-set reward-distribution-counter distribution-id)
                (var-set reward-pool (- available-pool total-distributed))
                
                (ok total-distributed)
            )
        )
    )
)

(define-public (update-contribution-score (member principal) (new-score uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (<= new-score u1000) err-invalid-contribution-score)
        
        (match (map-get? members member)
            member-data (begin
                (map-set members member (merge member-data {contribution-score: new-score}))
                
                ;; Update lifetime contribution score
                (match (map-get? member-rewards member)
                    reward-data (map-set member-rewards member (merge reward-data {
                        lifetime-contribution-score: (+ (get lifetime-contribution-score reward-data) new-score)
                    }))
                    false
                )
                (ok true)
            )
            err-not-member
        )
    )
)

(define-public (set-reward-multiplier (member principal) (multiplier uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (and (>= multiplier u50) (<= multiplier u200)) err-invalid-amount)
        
        (match (map-get? member-rewards member)
            reward-data (begin
                (map-set member-rewards member (merge reward-data {reward-multiplier: multiplier}))
                (ok true)
            )
            err-not-member
        )
    )
)

;; Private helper functions for rewards system
(define-private (update-member-contributions (member principal) (compensation uint) (complexity uint))
    (match (map-get? member-contributions member)
        contrib-data (begin
            (map-set member-contributions member (merge contrib-data {
                tasks-completed: (+ (get tasks-completed contrib-data) u1),
                total-compensation: (+ (get total-compensation contrib-data) compensation),
                last-active: stacks-block-height,
                average-rating: (/ (+ (* (get average-rating contrib-data) (get tasks-completed contrib-data)) complexity) 
                                  (+ (get tasks-completed contrib-data) u1))
            }))
            (try! (update-member-tier member))
            (ok true)
        )
        (begin
            (map-set member-contributions member {
                tasks-completed: u1,
                total-compensation: compensation,
                average-rating: complexity,
                last-active: stacks-block-height,
                current-tier: u0
            })
            (ok true)
        )
    )
)

(define-private (update-member-tier (member principal))
    (let (
        (contrib-data (unwrap! (map-get? member-contributions member) err-not-member))
        (task-count (get tasks-completed contrib-data))
        (total-earnings (get total-compensation contrib-data))
        (new-tier (calculate-tier task-count total-earnings))
    )
        (map-set member-contributions member (merge contrib-data {current-tier: new-tier}))
        (ok new-tier)
    )
)

(define-private (calculate-tier (task-count uint) (total-earnings uint))
    (if (and (>= task-count milestone-platinum-tasks) (>= total-earnings milestone-platinum-earnings))
        tier-platinum
        (if (and (>= task-count milestone-gold-tasks) (>= total-earnings milestone-gold-earnings))
            tier-gold
            (if (and (>= task-count milestone-silver-tasks) (>= total-earnings milestone-silver-earnings))
                tier-silver
                (if (and (>= task-count milestone-bronze-tasks) (>= total-earnings milestone-bronze-earnings))
                    tier-bronze
                    u0
                )
            )
        )
    )
)

(define-private (get-eligible-members-for-rewards)
    ;; This is a simplified version - in practice, you'd iterate through all members
    ;; For this implementation, we'll return a sample list structure
    (list tx-sender)
)

(define-private (distribute-rewards-to-members (members-list (list 100 principal)) (total-pool uint))
    (ok (let (
        (member-count (len members-list))
        (base-reward (/ total-pool member-count))
    )
        ;; Simplified distribution - in practice, you'd calculate individual rewards
        ;; based on contribution scores and multipliers
        (fold distribute-individual-reward members-list base-reward)
    ))
)

(define-private (distribute-individual-reward (member principal) (accumulated-total uint))
    (let (
        (member-data (default-to {voting-power: u0, joined-at: u0, total-earnings: u0, is-active: false, contribution-score: u0} 
                      (map-get? members member)))
        (reward-data (default-to {total-rewards-received: u0, last-reward-date: u0, reward-multiplier: u100, lifetime-contribution-score: u0}
                     (map-get? member-rewards member)))
        (contribution-score (get contribution-score member-data))
        (multiplier (get reward-multiplier reward-data))
        (base-reward (var-get base-reward-amount))
    )
        (if (and (get is-active member-data) (>= contribution-score minimum-contribution-threshold))
            (let (
                (individual-reward (/ (* base-reward multiplier contribution-score) u10000))
            )
                ;; Transfer reward (simplified - in practice, handle errors)
                (match (as-contract (stx-transfer? individual-reward tx-sender member))
                    success (begin
                        ;; Update member rewards record
                        (map-set member-rewards member (merge reward-data {
                            total-rewards-received: (+ (get total-rewards-received reward-data) individual-reward),
                            last-reward-date: stacks-block-height
                        }))
                        (+ accumulated-total individual-reward)
                    )
                    error accumulated-total
                )
            )
            accumulated-total
        )
    )
)

;; Read-only functions
(define-read-only (get-member (member principal))
    (map-get? members member)
)

(define-read-only (get-task (task-id uint))
    (map-get? tasks task-id)
)

(define-read-only (get-member-contributions (member principal))
    (map-get? member-contributions member)
)

(define-read-only (get-member-rewards (member principal))
    (map-get? member-rewards member)
)

(define-read-only (get-reward-distribution (distribution-id uint))
    (map-get? reward-distributions distribution-id)
)

(define-read-only (get-treasury-balance)
    (var-get treasury-balance)
)

(define-read-only (get-reward-pool)
    (var-get reward-pool)
)

(define-read-only (get-total-members)
    (var-get total-members)
)

(define-read-only (get-last-reward-distribution)
    (var-get last-reward-distribution)
)

(define-read-only (is-eligible-for-rewards (member principal))
    (match (map-get? members member)
        member-data (and 
            (get is-active member-data)
            (>= (get contribution-score member-data) minimum-contribution-threshold)
        )
        false
    )
)

(define-read-only (calculate-member-reward (member principal))
    (match (map-get? members member)
        member-data (match (map-get? member-rewards member)
            reward-data (let (
                (contribution-score (get contribution-score member-data))
                (multiplier (get reward-multiplier reward-data))
                (base-reward (var-get base-reward-amount))
            )
                (if (is-eligible-for-rewards member)
                    (/ (* base-reward multiplier contribution-score) u10000)
                    u0
                )
            )
            u0
        )
        u0
    )
)

(define-read-only (get-reward-distribution-stats)
    {
        current-pool: (var-get reward-pool),
        last-distribution: (var-get last-reward-distribution),
        next-distribution-eligible: (>= (- stacks-block-height (var-get last-reward-distribution)) reward-distribution-interval),
        distribution-counter: (var-get reward-distribution-counter)
    }
)

;; Helper function
(define-read-only (is-member (member principal))
    (match (map-get? members member)
        member-data (get is-active member-data)
        false
    )
)
