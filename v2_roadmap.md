# Finta V2 Roadmap & Feature Ideas

As Finta V1 successfully serves as a robust MVP for personal finance tracking, V2 is where we can elevate the app into a comprehensive, multi-platform, and highly intelligent financial manager. 

Below are the most impactful features we can add for the Version 2 release, drawing heavily from our previous discussions and modern personal finance trends.

## 1. Multiple Wallets & Accounts (High Priority)
*As discussed during the V1 development, this is the most requested feature.*
* **What it is:** Allow users to create distinct accounts (e.g., "Main Checking", "Credit Card", "Cash Wallet", "Savings"). 
* **How it works:** When adding a transaction, the user selects which wallet it came from. The Dashboard will show the total net worth across all wallets, as well as individual wallet balances.
* **Why it matters:** It provides a much more accurate picture of a user's financial health and allows them to track credit card debt vs. liquid cash.

## 2. Cloud Sync & Multi-Device Support (High Priority)
* **What it is:** Transition from purely local SQLite storage to a cloud-based backend (like Firebase Firestore or Supabase).
* **How it works:** Users can create an account (Google, Apple, or Email) to back up their data securely to the cloud. 
* **Why it matters:** Prevents data loss if a user loses or changes their phone, and allows them to access their budget from a tablet or a future web version of Finta.

## 3. Sub-categories
* **What it is:** Allow users to nest categories. For example, a parent category `Food & Drink` could have sub-categories for `Groceries`, `Restaurants`, and `Coffee Shops`.
* **Why it matters:** Gives power users the granular tracking they crave without cluttering the high-level pie charts.

## 4. Subscriptions & Recurring Bills Manager
* **What it is:** While Finta V1 supports recurring transactions, V2 could introduce a dedicated "Subscriptions" dashboard.
* **How it works:** A visually appealing screen that lists all active subscriptions (Netflix, Gym, Spotify), calculates the total monthly/yearly cost of these subscriptions, and sends a push notification 1 day before a charge is due.

## 5. AI Receipt Scanning (OCR)
* **What it is:** A camera button on the "Add Transaction" screen. 
* **How it works:** Utilizing Google ML Kit (which runs offline on the device for privacy), the app scans a physical receipt and automatically extracts the Merchant, Total Amount, and Date to pre-fill the transaction form.

## 6. Savings Goals & Sinking Funds
* **What it is:** Allow users to set specific financial goals (e.g., "New MacBook - $2,000" or "Emergency Fund - $10,000").
* **How it works:** Users can allocate a portion of their income directly towards these goals. The app displays progress bars and estimates when they will reach the goal based on their current saving rate.

## 7. Data Export & Reporting
* **What it is:** The ability to export transaction history to CSV, Excel, or PDF.
* **Why it matters:** Essential for users who need to do their taxes, submit expense reports to their employer, or do their own custom spreadsheet analysis.

## 8. Biometric Security (FaceID / Fingerprint)
* **What it is:** Add an option in the Settings menu to require biometric authentication to open the app.
* **Why it matters:** Finance apps contain highly sensitive data; locking the app adds a critical layer of privacy, especially for users who hand their phones to friends or children.

---

### Suggested Execution Plan for V2
If you decide to move forward with V2, I suggest we tackle it in these milestones to prevent breaking the app:
1. **Milestone 1:** Database Migration (Implement Wallets and Cloud Sync infrastructure).
2. **Milestone 2:** UI/UX Overhaul for Wallets, Subscriptions, and Savings Goals.
3. **Milestone 3:** AI Features (Receipt Scanning) and Polish (Biometrics, CSV Export).
