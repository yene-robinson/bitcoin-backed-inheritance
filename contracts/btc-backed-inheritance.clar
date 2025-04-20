;; Bitcoin-Backed Inheritance Protocol (BBIP)
;; Smart contract for decentralized inheritance management secured by Bitcoin's security model
;;
;; BBIP enables automated inheritance distribution with:
;; - Multi-oracle death verification with threshold signatures
;; - Time-locked distributions for controlled asset release
;; - Native NFT inheritance capabilities
;; - Dispute resolution mechanisms
;; - Phased inheritance release for risk management
;; - Full Bitcoin compliance through Stacks Layer 2 technology

(define-data-var contract-owner principal tx-sender)
(define-map oracles principal bool)
(define-data-var required-confirmations uint u2)
(define-data-var confirmation-count uint u0)
(define-map beneficiaries { beneficiary: principal } 
    { 
        share: uint, 
        claimed: bool,
        time-lock: uint,  ;; Block height for time-locked distributions
        nft-tokens: (list 10 uint)  ;; List of NFT IDs allocated
    })
(define-map nft-ownership uint principal)  ;; Track NFT ownership
(define-data-var total-shares uint u100)
(define-data-var is-active bool true)
(define-data-var death-confirmed bool false)
(define-data-var last-will-hash (buff 32) 0x)  ;; Hash of the last will document
(define-data-var inheritance-tax uint u2)  ;; 2% tax for contract maintenance

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-CLAIMED (err u101))
(define-constant ERR-INVALID-SHARE (err u102))
(define-constant ERR-NOT-ACTIVE (err u103))
(define-constant ERR-DEATH-NOT-CONFIRMED (err u104))
(define-constant ERR-TIME-LOCK (err u105))
(define-constant ERR-INVALID-NFT (err u106))
(define-constant ERR-INSUFFICIENT-CONFIRMATIONS (err u107))
(define-constant ERR-PHASE-1-NOT-CLAIMED (err u108))
(define-constant ERR-ALREADY-VOTED (err u109))
(define-constant ERR-NO-DISPUTE (err u110))
(define-constant ERR-INVALID-PRINCIPAL (err u111))
(define-constant ERR-INVALID-LOCK-PERIOD (err u112))
(define-constant ERR-INVALID-NFT-LIST (err u113))
(define-constant ERR-INVALID-HASH (err u114))
(define-constant ERR-DISPUTE-EXISTS (err u115))
(define-constant ERR-INVALID-CONFIRMATION-COUNT (err u116))

;; Helper function to check NFT validity
(define-private (check-nft-validity (token-id uint) (previous-valid bool))
    (and previous-valid (> token-id u0))
)

;; Helper function to validate NFT list
(define-private (valid-nft-list (nft-list (list 10 uint)))
    (fold check-nft-validity nft-list true)
)

;; Contract Administration Functions

;; Initialize contract with multiple oracles
(define-public (initialize-contract (oracle-list (list 5 principal)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (fold add-oracle oracle-list true)
        (ok true)
    )
)

;; Helper function to add oracle
(define-private (add-oracle (oracle principal) (previous bool))
    (begin
        (map-set oracles oracle true)
        true
    )
)

;; Add beneficiary with time-locked share and NFT allocation
(define-public (add-beneficiary (beneficiary principal) 
                               (share uint)
                               (lock-period uint)
                               (nft-list (list 10 uint)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (var-get is-active) ERR-NOT-ACTIVE)
        (asserts! (<= share u100) ERR-INVALID-SHARE)
        
        ;; Validate the principal is not zero address or contract address
        (asserts! (not (is-eq beneficiary 'SP000000000000000000002Q6VF78)) ERR-INVALID-PRINCIPAL)
        
        ;; Add validation for lock-period
        (asserts! (> lock-period u0) ERR-INVALID-LOCK-PERIOD)
        
        ;; Add validation for nft-list
        (asserts! (valid-nft-list nft-list) ERR-INVALID-NFT-LIST)
        
        (map-set beneficiaries 
            {beneficiary: beneficiary} 
            {
                share: share, 
                claimed: false,
                time-lock: (+ stacks-block-height lock-period),
                nft-tokens: nft-list
            })
        (ok true)
    )
)

;; Update last will document hash
(define-public (update-will-hash (new-hash (buff 32)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        ;; Check that hash is not empty
        (asserts! (not (is-eq new-hash 0x)) ERR-INVALID-HASH)
        (var-set last-will-hash new-hash)
        (ok true)
    )
)

;; Oracle Verification System

;; Oracle death confirmation with multi-sig requirement
(define-public (confirm-death)
    (begin
        (asserts! (default-to false (map-get? oracles tx-sender)) ERR-NOT-AUTHORIZED)
        (var-set confirmation-count (+ (var-get confirmation-count) u1))
        (if (>= (var-get confirmation-count) (var-get required-confirmations))
            (var-set death-confirmed true)
            false)
        (ok true)
    )
)

;; Inheritance Claim Functions

;; Helper function for NFT transfer
(define-private (transfer-nft (token-id uint))
    (begin
        ;; Verify the NFT ID is valid
        (if (> token-id u0)
            (begin
                ;; Set new ownership
                (map-set nft-ownership token-id tx-sender)
                (ok true))
            (err ERR-INVALID-NFT))
    )
)

;; Claim inheritance with time-lock and NFT transfer
(define-public (claim-inheritance)
    (let ((beneficiary-data (unwrap! (map-get? beneficiaries {beneficiary: tx-sender}) 
                                    ERR-NOT-AUTHORIZED)))
        (begin
            (asserts! (var-get death-confirmed) ERR-DEATH-NOT-CONFIRMED)
            (asserts! (not (get claimed beneficiary-data)) ERR-ALREADY-CLAIMED)
            (asserts! (>= stacks-block-height (get time-lock beneficiary-data)) ERR-TIME-LOCK)

            ;; Calculate share amount with inheritance tax
            (let ((share-amount (/ (* (stx-get-balance (as-contract tx-sender)) 
                                    (get share beneficiary-data)) 
                                 u100))
                  (tax-amount (/ (* share-amount (var-get inheritance-tax)) u100)))

                ;; Transfer NFTs
                (map transfer-nft (get nft-tokens beneficiary-data))

                ;; Update claimed status
                (map-set beneficiaries 
                    {beneficiary: tx-sender}
                    (merge beneficiary-data {claimed: true}))

                ;; Transfer share minus tax
                (as-contract
                    (stx-transfer? (- share-amount tax-amount) 
                                 contract-caller tx-sender)
                )
            )
        )
    )
)

;; Phased Inheritance Release

(define-map inheritance-phases 
    { beneficiary: principal } 
    {
        phase-1-claimed: bool,
        phase-2-claimed: bool,
        phase-1-amount: uint,
        phase-2-amount: uint
    }
)

;; Claim phased inheritance
(define-private (claim-phase-1 (phase-data {phase-1-claimed: bool, phase-2-claimed: bool, phase-1-amount: uint, phase-2-amount: uint}))
    (begin
        (asserts! (not (get phase-1-claimed phase-data)) ERR-ALREADY-CLAIMED)
        (let ((amount (/ (* (stx-get-balance (as-contract tx-sender)) 
                          (get phase-1-amount phase-data)) 
                       u100)))
            (begin
                (map-set inheritance-phases 
                    {beneficiary: tx-sender}
                    (merge phase-data {phase-1-claimed: true}))
                (as-contract
                    (stx-transfer? amount contract-caller tx-sender))
            )
        )
    )
)

;; Dispute Resolution System

(define-map disputes 
    { disputer: principal } 
    { 
        evidence-hash: (buff 32), 
        resolved: bool 
    }
)

(define-map dispute-metadata
    { disputer: principal }
    {
        resolution-votes: uint,
        timestamp: uint
    }
)

(define-map resolution-votes 
    { dispute-id: principal, voter: principal } 
    bool
)

;; Voting threshold for dispute resolution
(define-data-var resolution-threshold uint u3)

;; Raise a dispute with evidence
(define-public (raise-dispute (evidence-hash (buff 32)))
    (let ((beneficiary-data (unwrap! (map-get? beneficiaries {beneficiary: tx-sender}) ERR-NOT-AUTHORIZED)))
        (begin
            ;; Check that evidence hash is not empty
            (asserts! (not (is-eq evidence-hash 0x)) ERR-INVALID-HASH)
            
            ;; Check if dispute already exists
            (asserts! (is-none (map-get? disputes {disputer: tx-sender})) ERR-DISPUTE-EXISTS)
            
            (map-set disputes 
                {disputer: tx-sender}
                {evidence-hash: evidence-hash, resolved: false})
            (ok true))
    )
)

;; Automatic dispute resolution
(define-private (resolve-dispute (disputer principal))
    (match (map-get? disputes {disputer: disputer})
        dispute-data (begin
            (map-set disputes 
                {disputer: disputer}
                (merge dispute-data {resolved: true}))
            true)
        false
    )
)

;; Emergency and Administrative Functions

(define-public (deactivate-contract)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set is-active false)
        (ok true)
    )
)

(define-public (update-required-confirmations (new-count uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        ;; Validate new confirmation count
        (asserts! (> new-count u0) ERR-INVALID-CONFIRMATION-COUNT)
        (var-set required-confirmations new-count)
        (ok true)
    )
)

;; Read-Only Functions

;; Enhanced getters
(define-read-only (get-beneficiary-info (beneficiary principal))
    (map-get? beneficiaries {beneficiary: beneficiary})
)

(define-read-only (get-contract-status)
    {
        active: (var-get is-active),
        death-confirmed: (var-get death-confirmed),
        confirmation-count: (var-get confirmation-count),
        required-confirmations: (var-get required-confirmations),
        last-will-hash: (var-get last-will-hash),
        inheritance-tax: (var-get inheritance-tax)
    }
)

(define-read-only (get-nft-owner (token-id uint))
    (map-get? nft-ownership token-id)
)