# V1 vs V2 Screen Comparison Prompt

Use this prompt to systematically compare a V1 screen/component to its V2 equivalent, gather requirements decisions, and create actionable output.

---

## Prompt

Compare the V1 and V2 implementations of a screen or component, then help me decide what V2 should include.

### Step 1: Identify the screens

Ask me which V1 file/screen and V2 file/screen to compare. If I haven't specified them, prompt me:

> What V1 screen/component should I analyze? (provide file path, e.g., `v1/components/imageedit.tsx` or `v1/pages/admin/images.tsx`)
>
> What is the corresponding V2 screen/component? (provide file path, e.g., `lib/gallformers_web/live/admin/images_live.ex`)

### Step 2: Analyze both implementations

Read both files thoroughly and create a detailed comparison covering:

**Fields:**
- List every field/input in V1
- List every field/input in V2
- Note data types (text, textarea, select, checkbox, typeahead, etc.)
- Note any validation or required indicators

**UI/UX Features:**
- Layout and visual elements (thumbnails, previews, etc.)
- Help text, tooltips, InfoTips
- Informational displays (read-only data like timestamps, usernames)
- State indicators (dirty state, loading, errors)
- Navigation and flow

**Behavior:**
- Auto-population or field dependencies
- Conditional rendering (fields that show/hide based on other values)
- Form submission handling
- Cancel/discard behavior

**Data Sources:**
- What data is fetched/loaded
- What APIs or contexts are used

### Step 3: Present comparison table

Create a markdown table summarizing findings:

| Item | V1 | V2 | Status |
|------|----|----|--------|
| [field/feature name] | [V1 implementation] | [V2 implementation or "Missing"] | [Same/Enhanced/Missing/Different] |

### Step 4: Gather decisions one by one

For EACH item where V1 and V2 differ (missing, different approach, or could be enhanced), ask me what to do using the AskUserQuestion tool:

- Present the V1 behavior clearly
- Present the V2 behavior (or note it's missing)
- Offer sensible options (add it, skip it, modify it, backlog it, etc.)
- Mark one option as "(Recommended)" if there's an obvious best choice

### Step 5: Ask about missed items

After going through all items, ask:

> Is there anything I missed in this comparison? Any V1 features I didn't mention, or any V2 improvements you want that weren't in V1?

If the user mentions additional items, add them to the decisions list.

### Step 6: Summarize and ask what to do

Present a summary table of all decisions made:

| Item | Decision |
|------|----------|
| [item name] | [what was decided] |

Then ask what to do with these decisions:

> What would you like to do with these requirements?
>
> - **Create a bead** - Save as an issue for later implementation
> - **Work on it now** - Start implementing these changes immediately
> - **Edit the list** - Modify or refine the decisions
> - **Export as markdown** - Save to a file for reference
> - **Nothing for now** - Just keep in conversation context

### Step 7: Execute the chosen action

- **Create a bead**: Use `bd create` with a descriptive title, type=feature or task, and include all decisions in the description
- **Work on it now**: Begin implementation, using TodoWrite to track progress
- **Edit the list**: Ask which items to change and update accordingly
- **Export**: Write to a file in `docs/` or user-specified location

---

## Example Usage

User: "Compare the V1 and V2 gall admin forms"

Assistant will:
1. Read `v1/pages/admin/gall/[id].tsx` (or similar) and `lib/gallformers_web/live/admin/gall_live/form.ex`
2. Create comparison table
3. Ask about each differing item
4. Ask if anything was missed
5. Summarize decisions
6. Ask what to do with the list
7. Execute chosen action
