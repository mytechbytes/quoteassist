from __future__ import annotations


def overall_confidence(
    mandatory_completeness: float,
    avg_field_confidence: float,
    date_location_validation: float,
    pricing_readiness: float,
) -> float:
    """Weighted overall confidence (VC-03). Store the breakdown, not just this."""
    return round(
        mandatory_completeness * 0.40
        + avg_field_confidence * 0.30
        + date_location_validation * 0.20
        + pricing_readiness * 0.10,
        4,
    )
