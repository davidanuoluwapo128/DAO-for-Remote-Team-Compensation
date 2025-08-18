(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-not-member (err u101))
(define-constant err-task-not-found (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-voting-closed (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-task-already-executed (err u107))
(define-constant err-minimum-approval-not-met (err u108))
(define-constant err-invalid-milestone (err u109))

(define-constant milestone-bronze-tasks u5)
(define-constant milestone-silver-tasks u15)
(define-constant milestone-gold-tasks u35)
(define-constant milestone-platinum-tasks u75)

(define-constant milestone-bronze-earnings u500)
(define-constant milestone-silver-earnings u2000)
(define-constant milestone-gold-earnings u6000)
(define-constant milestone-platinum-earnings u15000)

(define-constant tier-bronze u1)
(define-constant tier-silver u2)
(define-constant tier-gold u3)
(define-constant tier-platinum u4)

(define-data-var total-members uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var task-counter uint u0)
(define-data-var minimum-approval-percentage uint u60)

(define-map members principal {
    voting-power: uint,
    joined-at: uint,
    total-earnings: uint,
    is-active: bool
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
    last-active: uint
})

(define-map member-milestones principal {
    current-tier: uint,
    tier-achieved-at: uint,
    bronze-achieved: bool,
    silver-achieved: bool,
    gold-achieved: bool,
    platinum-achieved: bool
})

(define-public (initialize-dao)
    (begin
        (try! (add-member contract-owner u100))
        (var-set treasury-balance u0)
        (ok true)
    )
)

(define-public (add-member (new-member principal) (voting-power uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (> voting-power u0) err-invalid-amount)
        (map-set members new-member {
            voting-power: voting-power,
            joined-at: stacks-block-height,
            total-earnings: u0,
            is-active: true
        })
        (var-set total-members (+ (var-get total-members) u1))
        (map-set member-milestones new-member {
            current-tier: u0,
            tier-achieved-at: u0,
            bronze-achieved: false,
            silver-achieved: false,
            gold-achieved: false,
            platinum-achieved: false
        })
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

(define-public (deposit-to-treasury (amount uint))
    (begin
        (asserts! (> amount u0) err-invalid-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (ok true)
    )
)

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
    )
        (asserts! (> stacks-block-height (get voting-deadline task-data)) err-voting-closed)
        (asserts! (not (get is-executed task-data)) err-task-already-executed)
        (asserts! (>= approval-rate (var-get minimum-approval-percentage)) err-minimum-approval-not-met)
        (asserts! (>= (var-get treasury-balance) compensation) err-insufficient-funds)
        
        (try! (as-contract (stx-transfer? compensation tx-sender creator)))
        (var-set treasury-balance (- (var-get treasury-balance) compensation))
        
        (map-set tasks task-id (merge task-data {is-executed: true}))
        
        (match (map-get? members creator)
            member-data (map-set members creator (merge member-data {
                total-earnings: (+ (get total-earnings member-data) compensation)
            }))
            false
        )
        
        (match (map-get? member-contributions creator)
            contrib-data (map-set member-contributions creator (merge contrib-data {
                tasks-completed: (+ (get tasks-completed contrib-data) u1),
                total-compensation: (+ (get total-compensation contrib-data) compensation),
                last-active: stacks-block-height
            }))
            (map-set member-contributions creator {
                tasks-completed: u1,
                total-compensation: compensation,
                average-rating: (get complexity task-data),
                last-active: stacks-block-height
            })
        )
        (try! (update-member-milestone creator))
        (ok true)
    )
)

(define-public (update-minimum-approval (new-percentage uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (and (>= new-percentage u1) (<= new-percentage u100)) err-invalid-amount)
        (var-set minimum-approval-percentage new-percentage)
        (ok true)
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

(define-public (update-member-milestone (member principal))
    (let (
        (contrib-data (unwrap! (map-get? member-contributions member) err-not-member))
        (milestone-data (unwrap! (map-get? member-milestones member) err-not-member))
        (task-count (get tasks-completed contrib-data))
        (total-earnings (get total-compensation contrib-data))
        (new-tier (calculate-tier task-count total-earnings))
        (current-tier (get current-tier milestone-data))
        (member-data (unwrap! (map-get? members member) err-not-member))
        (base-voting-power (get voting-power member-data))
    )
        (if (> new-tier current-tier)
            (let (
                (tier-multiplier (if (is-eq new-tier tier-platinum) u4
                                 (if (is-eq new-tier tier-gold) u3
                                 (if (is-eq new-tier tier-silver) u2
                                 (if (is-eq new-tier tier-bronze) u1 u1)))))
                (new-voting-power (* base-voting-power (+ u1 tier-multiplier)))
            )
                (map-set member-milestones member {
                    current-tier: new-tier,
                    tier-achieved-at: stacks-block-height,
                    bronze-achieved: (or (get bronze-achieved milestone-data) (is-eq new-tier tier-bronze)),
                    silver-achieved: (or (get silver-achieved milestone-data) (is-eq new-tier tier-silver)),
                    gold-achieved: (or (get gold-achieved milestone-data) (is-eq new-tier tier-gold)),
                    platinum-achieved: (or (get platinum-achieved milestone-data) (is-eq new-tier tier-platinum))
                })
                (map-set members member (merge member-data {voting-power: new-voting-power}))
                (ok true)
            )
            (ok false)
        )
    )
)

(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (<= amount (var-get treasury-balance)) err-insufficient-funds)
        (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (ok true)
    )
)

(define-read-only (get-member (member principal))
    (map-get? members member)
)

(define-read-only (get-task (task-id uint))
    (map-get? tasks task-id)
)

(define-read-only (get-task-vote (task-id uint) (voter principal))
    (map-get? task-votes {task-id: task-id, voter: voter})
)

(define-read-only (get-member-contributions (member principal))
    (map-get? member-contributions member)
)

(define-read-only (get-treasury-balance)
    (var-get treasury-balance)
)

(define-read-only (get-total-members)
    (var-get total-members)
)

(define-read-only (get-task-counter)
    (var-get task-counter)
)

(define-read-only (get-minimum-approval-percentage)
    (var-get minimum-approval-percentage)
)

(define-read-only (is-task-approved (task-id uint))
    (match (map-get? tasks task-id)
        task-data (let (
            (total-votes (+ (get yes-votes task-data) (get no-votes task-data)))
            (approval-rate (if (> total-votes u0) 
                (* (/ (get yes-votes task-data) total-votes) u100) 
                u0))
        )
            (>= approval-rate (var-get minimum-approval-percentage))
        )
        false
    )
)

(define-read-only (get-voting-status (task-id uint))
    (match (map-get? tasks task-id)
        task-data {
            yes-votes: (get yes-votes task-data),
            no-votes: (get no-votes task-data),
            voting-active: (<= stacks-block-height (get voting-deadline task-data)),
            is-executed: (get is-executed task-data)
        }
        {yes-votes: u0, no-votes: u0, voting-active: false, is-executed: false}
    )
)

(define-read-only (calculate-member-reputation (member principal))
    (match (map-get? member-contributions member)
        contrib-data (let (
            (tasks-completed (get tasks-completed contrib-data))
            (avg-rating (get average-rating contrib-data))
        )
            (if (> tasks-completed u0)
                (+ (* tasks-completed u10) (* avg-rating u5))
                u0
            )
        )
        u0
    )
)

(define-read-only (get-member-milestone (member principal))
    (map-get? member-milestones member)
)

(define-read-only (get-member-tier (member principal))
    (match (map-get? member-milestones member)
        milestone-data (get current-tier milestone-data)
        u0
    )
)

(define-read-only (get-tier-name (tier uint))
    (if (is-eq tier tier-platinum)
        "Platinum"
        (if (is-eq tier tier-gold)
            "Gold"
            (if (is-eq tier tier-silver)
                "Silver"
                (if (is-eq tier tier-bronze)
                    "Bronze"
                    "None"
                )
            )
        )
    )
)

(define-read-only (check-milestone-eligibility (member principal))
    (match (map-get? member-contributions member)
        contrib-data (let (
            (task-count (get tasks-completed contrib-data))
            (total-earnings (get total-compensation contrib-data))
            (next-tier (calculate-tier task-count total-earnings))
        )
            {
                eligible-tier: next-tier,
                tasks-completed: task-count,
                total-earnings: total-earnings,
                bronze-progress: {
                    tasks-needed: (if (>= task-count milestone-bronze-tasks) u0 (- milestone-bronze-tasks task-count)),
                    earnings-needed: (if (>= total-earnings milestone-bronze-earnings) u0 (- milestone-bronze-earnings total-earnings))
                },
                silver-progress: {
                    tasks-needed: (if (>= task-count milestone-silver-tasks) u0 (- milestone-silver-tasks task-count)),
                    earnings-needed: (if (>= total-earnings milestone-silver-earnings) u0 (- milestone-silver-earnings total-earnings))
                },
                gold-progress: {
                    tasks-needed: (if (>= task-count milestone-gold-tasks) u0 (- milestone-gold-tasks task-count)),
                    earnings-needed: (if (>= total-earnings milestone-gold-earnings) u0 (- milestone-gold-earnings total-earnings))
                },
                platinum-progress: {
                    tasks-needed: (if (>= task-count milestone-platinum-tasks) u0 (- milestone-platinum-tasks task-count)),
                    earnings-needed: (if (>= total-earnings milestone-platinum-earnings) u0 (- milestone-platinum-earnings total-earnings))
                }
            }
        )
        {
            eligible-tier: u0,
            tasks-completed: u0,
            total-earnings: u0,
            bronze-progress: {tasks-needed: milestone-bronze-tasks, earnings-needed: milestone-bronze-earnings},
            silver-progress: {tasks-needed: milestone-silver-tasks, earnings-needed: milestone-silver-earnings},
            gold-progress: {tasks-needed: milestone-gold-tasks, earnings-needed: milestone-gold-earnings},
            platinum-progress: {tasks-needed: milestone-platinum-tasks, earnings-needed: milestone-platinum-earnings}
        }
    )
)
