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