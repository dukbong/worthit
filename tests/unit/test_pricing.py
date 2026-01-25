#!/usr/bin/env python3
"""
Unit tests for pricing calculations and cost accuracy.

These tests verify that cost calculations match official Anthropic pricing
and that the pricing information is kept up-to-date.
"""

import unittest
import json
import sys
import os

# Add src directory to path to import worthit_core
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src'))

# Import functions from worthit_core module
from worthit_core import get_pricing, calculate_cost, format_cost


class TestPricingAccuracy(unittest.TestCase):
    """Test that pricing matches official Anthropic rates"""

    def test_opus_pricing(self):
        """Verify Opus 4.5 pricing matches official rates"""
        pricing = get_pricing("claude-opus-4-5-20251101")

        # Official rates: $5/1M input, $25/1M output
        self.assertEqual(pricing['input'], 0.000005)  # $5 / 1,000,000
        self.assertEqual(pricing['output'], 0.000025)  # $25 / 1,000,000
        self.assertEqual(pricing['cache_write'], 0.00000625)  # $6.25 / 1,000,000
        self.assertEqual(pricing['cache_read'], 0.0000005)  # $0.50 / 1,000,000

    def test_sonnet_pricing(self):
        """Verify Sonnet 4.5 pricing matches official rates"""
        pricing = get_pricing("claude-sonnet-4-5-20250929")

        # Official rates: $3/1M input, $15/1M output
        self.assertEqual(pricing['input'], 0.000003)  # $3 / 1,000,000
        self.assertEqual(pricing['output'], 0.000015)  # $15 / 1,000,000
        self.assertEqual(pricing['cache_write'], 0.00000375)  # $3.75 / 1,000,000
        self.assertEqual(pricing['cache_read'], 0.0000003)  # $0.30 / 1,000,000

    def test_haiku_pricing(self):
        """Verify Haiku 4.5 pricing matches official rates"""
        pricing = get_pricing("claude-haiku-4-5-20250110")

        # Official rates: $1/1M input, $5/1M output
        self.assertEqual(pricing['input'], 0.000001)  # $1 / 1,000,000
        self.assertEqual(pricing['output'], 0.000005)  # $5 / 1,000,000
        self.assertEqual(pricing['cache_write'], 0.00000125)  # $1.25 / 1,000,000
        self.assertEqual(pricing['cache_read'], 0.0000001)  # $0.10 / 1,000,000

    def test_default_to_sonnet(self):
        """Should default to Sonnet pricing for unknown models"""
        pricing = get_pricing("unknown-model")
        sonnet_pricing = get_pricing("sonnet")
        self.assertEqual(pricing, sonnet_pricing)

    def test_case_insensitive(self):
        """Should be case-insensitive for model names"""
        opus_lower = get_pricing("opus")
        opus_upper = get_pricing("OPUS")
        opus_mixed = get_pricing("OpUs")

        self.assertEqual(opus_lower, opus_upper)
        self.assertEqual(opus_lower, opus_mixed)


class TestCostCalculation(unittest.TestCase):
    """Test cost calculation accuracy"""

    def test_sonnet_cost_calculation(self):
        """Test cost calculation for Sonnet"""
        pricing = get_pricing("sonnet")
        totals = {
            'input': 1000,
            'output': 500,
            'cache_write': 200,
            'cache_read': 100
        }

        cost = calculate_cost(totals, pricing)

        # Expected: 1000*0.000003 + 500*0.000015 + 200*0.00000375 + 100*0.0000003
        #         = 0.003 + 0.0075 + 0.00075 + 0.00003
        #         = 0.01128
        self.assertAlmostEqual(cost, 0.01128, places=6)

    def test_opus_cost_calculation(self):
        """Test cost calculation for Opus"""
        pricing = get_pricing("opus")
        totals = {
            'input': 1000,
            'output': 500,
            'cache_write': 0,
            'cache_read': 0
        }

        cost = calculate_cost(totals, pricing)

        # Expected: 1000*0.000005 + 500*0.000025
        #         = 0.005 + 0.0125
        #         = 0.0175
        self.assertAlmostEqual(cost, 0.0175, places=6)

    def test_haiku_cost_calculation(self):
        """Test cost calculation for Haiku"""
        pricing = get_pricing("haiku")
        totals = {
            'input': 10000,
            'output': 5000,
            'cache_write': 0,
            'cache_read': 0
        }

        cost = calculate_cost(totals, pricing)

        # Expected: 10000*0.000001 + 5000*0.000005
        #         = 0.01 + 0.025
        #         = 0.035
        self.assertAlmostEqual(cost, 0.035, places=6)

    def test_zero_tokens(self):
        """Should return zero cost for zero tokens"""
        pricing = get_pricing("sonnet")
        totals = {
            'input': 0,
            'output': 0,
            'cache_write': 0,
            'cache_read': 0
        }

        cost = calculate_cost(totals, pricing)
        self.assertEqual(cost, 0.0)

    def test_cache_only_cost(self):
        """Test cost calculation with only cache tokens"""
        pricing = get_pricing("sonnet")
        totals = {
            'input': 0,
            'output': 0,
            'cache_write': 1000,
            'cache_read': 1000
        }

        cost = calculate_cost(totals, pricing)

        # Expected: 1000*0.00000375 + 1000*0.0000003
        #         = 0.00375 + 0.0003
        #         = 0.00405
        self.assertAlmostEqual(cost, 0.00405, places=6)


class TestCostFormatting(unittest.TestCase):
    """Test cost formatting for display"""

    def test_format_small_cost(self):
        """Should use 6 decimal places for costs < $0.0001"""
        cost = 0.000056
        formatted = format_cost(cost)
        self.assertEqual(formatted, "$0.000056")

    def test_format_medium_cost(self):
        """Should use 4 decimal places for costs >= $0.0001"""
        cost = 0.0123
        formatted = format_cost(cost)
        self.assertEqual(formatted, "$0.0123")

    def test_format_large_cost(self):
        """Should use 4 decimal places for larger costs"""
        cost = 1.2345
        formatted = format_cost(cost)
        self.assertEqual(formatted, "$1.2345")

    def test_format_very_small_cost(self):
        """Should handle very small costs"""
        cost = 0.0000001
        formatted = format_cost(cost)
        self.assertEqual(formatted, "$0.000000")

    def test_format_zero_cost(self):
        """Should format zero cost"""
        cost = 0.0
        formatted = format_cost(cost)
        self.assertIn("$0.0", formatted)


class TestRealWorldScenarios(unittest.TestCase):
    """Test realistic usage scenarios"""

    def test_typical_conversation_opus(self):
        """Test cost for typical Opus conversation"""
        pricing = get_pricing("opus")
        # Typical: 2000 input, 500 output
        totals = {
            'input': 2000,
            'output': 500,
            'cache_write': 0,
            'cache_read': 0
        }

        cost = calculate_cost(totals, pricing)

        # Should be around $0.0225
        self.assertLess(cost, 0.03)
        self.assertGreater(cost, 0.02)

    def test_large_conversation_with_cache(self):
        """Test cost for large conversation with caching"""
        pricing = get_pricing("sonnet")
        # Large conversation with cache hits
        totals = {
            'input': 5000,
            'output': 3000,
            'cache_write': 500,
            'cache_read': 1000
        }

        cost = calculate_cost(totals, pricing)

        # Should be reasonable (less than $0.10)
        self.assertLess(cost, 0.1)
        self.assertGreater(cost, 0.05)

    def test_haiku_quick_query(self):
        """Test cost for quick Haiku query"""
        pricing = get_pricing("haiku")
        # Quick query: 100 input, 50 output
        totals = {
            'input': 100,
            'output': 50,
            'cache_write': 0,
            'cache_read': 0
        }

        cost = calculate_cost(totals, pricing)

        # Should be very cheap (< $0.001)
        self.assertLess(cost, 0.001)


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)
