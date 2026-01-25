# Pricing Information and Transparency

This document explains how Worthit calculates API costs and our commitment to maintaining accurate pricing information.

## Why Self-Calculate Costs?

**Claude CLI transcripts don't include cost data.** The transcript files only record token counts (input, output, cache read, cache write) but not the associated costs.

Worthit performs client-side cost calculations to provide you with:

- **Instant feedback**: See costs immediately after each conversation turn
- **Offline capability**: Works without additional API calls to Anthropic
- **Privacy**: All calculations happen locally on your machine
- **Historical accuracy**: Costs are based on the model actually used

### Alternative Approaches Considered

We evaluated several approaches before choosing client-side calculation:

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **Client-side calculation** ✅ | Fast, offline, private | Requires manual updates | **Chosen** |
| API cost lookup | Always current | Network required, latency, privacy | Rejected |
| Parse billing statements | Accurate | Delayed, complex parsing | Rejected |
| Rely on Claude CLI | Simple | Not available in transcripts | Not possible |

## Current Pricing

**Last verified**: January 25, 2025
**Source**: https://www.anthropic.com/pricing

### Claude 4.5 Models

| Model | Input Tokens | Output Tokens | Cache Write | Cache Read |
|-------|-------------|---------------|-------------|------------|
| **Opus 4.5** | $5.00 / 1M | $25.00 / 1M | $6.25 / 1M | $0.50 / 1M |
| **Sonnet 4.5** | $3.00 / 1M | $15.00 / 1M | $3.75 / 1M | $0.30 / 1M |
| **Haiku 4.5** | $1.00 / 1M | $5.00 / 1M | $1.25 / 1M | $0.10 / 1M |

### Price Breakdown

#### Opus 4.5 (Premium Performance)
- **Input**: $0.000005 per token ($5 per million)
- **Output**: $0.000025 per token ($25 per million)
- **Cache Write**: $0.00000625 per token (1.25× input rate)
- **Cache Read**: $0.0000005 per token (0.1× input rate)

#### Sonnet 4.5 (Balanced)
- **Input**: $0.000003 per token ($3 per million)
- **Output**: $0.000015 per token ($15 per million)
- **Cache Write**: $0.00000375 per token (1.25× input rate)
- **Cache Read**: $0.0000003 per token (0.1× input rate)

#### Haiku 4.5 (Fast & Cost-Effective)
- **Input**: $0.000001 per token ($1 per million)
- **Output**: $0.000005 per token ($5 per million)
- **Cache Write**: $0.00000125 per token (1.25× input rate)
- **Cache Read**: $0.0000001 per token (0.1× input rate)

## How Pricing is Implemented

### Code Location

Pricing is hardcoded in the `get_pricing()` function in each platform script:

- **Linux**: `src/worthit-linux.sh` (lines 15-71)
- **macOS**: `src/worthit-macos.sh` (lines 15-71)
- **Windows**: `src/worthit-windows.sh` (lines 15-71)

### Calculation Formula

```python
total_cost = (
    input_tokens × input_rate +
    output_tokens × output_rate +
    cache_write_tokens × cache_write_rate +
    cache_read_tokens × cache_read_rate
)
```

### Example Calculation

For a Sonnet 4.5 conversation with:
- 1,500 input tokens
- 500 output tokens
- 200 cache write tokens
- 100 cache read tokens

```
Cost = (1500 × $0.000003) + (500 × $0.000015) + (200 × $0.00000375) + (100 × $0.0000003)
     = $0.0045 + $0.0075 + $0.00075 + $0.00003
     = $0.01278
```

**Displayed as**: `$0.0128` (rounded to 4 decimal places)

## Pricing Accuracy Guarantee

### Verification Schedule

- **Monthly verification**: First day of each month
- **Process**:
  1. Visit https://www.anthropic.com/pricing
  2. Compare published rates with our hardcoded values
  3. Update code if discrepancies found
  4. Run full test suite to verify calculations
  5. Release update within 48 hours

### Last Verification

- **Date**: January 25, 2025
- **Verified by**: Project maintainer
- **Status**: ✅ All prices match official rates
- **Next verification**: February 1, 2025

### Update History

| Date | Change | Version |
|------|--------|---------|
| 2025-01-25 | Initial pricing documentation | v1.0.0 |
| 2024-12-10 | Haiku 4.5 pricing correction ($1/$5) | v0.9.0 |

## How to Report Pricing Issues

If you notice a discrepancy between our calculated costs and your Anthropic billing:

### 1. Check Your Comparison

- Ensure you're comparing the **same conversation** (matching tokens)
- Account for **rounding differences** (we show 4-6 decimal places)
- Verify the **model used** (Opus vs. Sonnet vs. Haiku)
- Include **cache tokens** in your calculation

### 2. Report the Issue

Open a GitHub Issue with the `pricing-discrepancy` label:

**Required information**:
- Date of conversation
- Model used
- Token counts (input, output, cache write, cache read)
- Worthit calculated cost
- Expected cost (from billing or official pricing page)
- Screenshot of Anthropic pricing page

**Example report**:
```
**Model**: Sonnet 4.5
**Tokens**: 1000 input, 500 output, 0 cache
**Worthit cost**: $0.0105
**Expected cost**: $0.0108 (based on billing)
**Pricing page**: [screenshot]
```

### 3. Expected Response Time

- **Acknowledgment**: Within 24 hours
- **Investigation**: Within 48 hours
- **Fix (if needed)**: Within 72 hours
- **Release**: Within 7 days

## Pricing Update Process

When Anthropic changes their pricing:

### 1. Detection
- Monthly verification check
- User reports via GitHub Issues
- Automated tests fail (if rates change)

### 2. Verification
- Confirm change on official pricing page
- Document old vs. new rates
- Calculate impact on example conversations

### 3. Code Update
- Update `get_pricing()` function in all three scripts
- Update this documentation
- Update test cases in `tests/unit/test_pricing.py`

### 4. Testing
- Run unit tests: `python3 tests/unit/test_pricing.py`
- Run integration tests: `tests/integration/test_full_flow.sh`
- Manual verification with real transcripts

### 5. Release
- Create Git tag with version bump
- Update CHANGELOG.md
- Publish GitHub release
- Notify users via Discussions

## Transparency Commitment

We commit to:

- ✅ **Monthly verification** of all pricing information
- ✅ **48-hour response** to pricing discrepancy reports
- ✅ **Public documentation** of all pricing changes
- ✅ **Comprehensive test coverage** for pricing calculations
- ✅ **Clear update history** in this document

## FAQ

### Why not use the Anthropic API to get current prices?

This would require:
- Network connection (breaks offline use)
- API authentication (privacy concern)
- Additional latency (slower notifications)
- More complex code (harder to audit)

Our approach is simpler, faster, and more private.

### How often do Claude prices change?

Historically, Anthropic has adjusted pricing:
- During major model releases
- When introducing new features (like prompt caching)
- Approximately 2-4 times per year

We verify monthly and respond quickly to changes.

### What if I find a discrepancy?

Please report it via GitHub Issues. We take pricing accuracy seriously and will investigate within 48 hours.

### Can I verify the calculations myself?

Yes! The code is open source:
1. View `src/worthit-linux.sh` (or your platform)
2. Find the `get_pricing()` function
3. Compare rates with https://www.anthropic.com/pricing
4. Run tests: `python3 tests/unit/test_pricing.py`

### Do you round costs?

Yes, for display:
- Costs < $0.0001: shown with 6 decimal places
- Costs ≥ $0.0001: shown with 4 decimal places

Internal calculations use full precision (Python float64).

## Contact

- **Pricing issues**: [GitHub Issues](https://github.com/dukbong/worthit/issues) with `pricing-discrepancy` label
- **General questions**: [GitHub Discussions](https://github.com/dukbong/worthit/discussions)
- **Documentation updates**: Pull requests welcome

---

**Last updated**: January 25, 2025
**Document version**: 1.0.0
**Pricing version**: Claude 4.5 (2025-01-25)
