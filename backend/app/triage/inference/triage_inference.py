import numpy as np
import xgboost as xgb

from app.core.config import settings
from app.core.logging import logger


_priority_model = None
_urgency_model = None
_impact_model = None

PRIORITY_LABEL_MAP = {0: 2, 1: 3, 2: 4, 3: 5}
URGENCY_LABEL_MAP = {0: 2, 1: 3, 2: 4, 3: 5}
IMPACT_LABEL_MAP = {0: 3, 1: 4, 2: 5}

PRIORITY_NAME_MAP = {2: "Low", 3: "Medium", 4: "High", 5: "Critical"}
URGENCY_NAME_MAP = {2: "Low", 3: "Medium", 4: "High", 5: "Critical"}
IMPACT_NAME_MAP = {3: "Medium", 4: "High", 5: "Critical"}

FEATURE_NAMES = [
    "text_word_count",
    "text_char_count",
    "avg_word_length",
    "special_char_ratio",
    "text_complexity_score",
    "retrieval_quality_score",
    "corpus_quality_score",
    "similarity_confidence",
]


def _load_xgb(path: str) -> xgb.XGBClassifier:
    resolved = settings.resolve_path(path)
    logger.info("Loading XGBoost model from %s", resolved)
    model = xgb.XGBClassifier()
    model.load_model(resolved)
    logger.info("XGBoost model loaded: %s", resolved)
    return model


def get_priority_model():
    global _priority_model
    if _priority_model is None:
        _priority_model = _load_xgb(settings.xgb_priority_path)
    return _priority_model


def get_urgency_model():
    global _urgency_model
    if _urgency_model is None:
        _urgency_model = _load_xgb(settings.xgb_urgency_path)
    return _urgency_model


def get_impact_model():
    global _impact_model
    if _impact_model is None:
        _impact_model = _load_xgb(settings.xgb_impact_path)
    return _impact_model


def compute_escalation_risk(priority: int, urgency: int, impact: int) -> float:
    priority_norm = (priority - 2) / (5 - 2)
    urgency_norm = (urgency - 2) / (5 - 2)
    impact_norm = (impact - 3) / (5 - 3)

    weights = {"priority": 0.5, "urgency": 0.3, "impact": 0.2}

    risk = (
        weights["priority"] * priority_norm
        + weights["urgency"] * urgency_norm
        + weights["impact"] * impact_norm
    )
    return round(min(max(risk, 0.0), 1.0), 4)


def predict_triage(features: dict) -> dict:
    logger.info("Predicting triage for feature vector")

    input_array = np.array([[features[f] for f in FEATURE_NAMES]], dtype=np.float32)

    priority_model = get_priority_model()
    urgency_model = get_urgency_model()
    impact_model = get_impact_model()

    priority_enc = int(priority_model.predict(input_array)[0])
    urgency_enc = int(urgency_model.predict(input_array)[0])
    impact_enc = int(impact_model.predict(input_array)[0])

    priority = PRIORITY_LABEL_MAP[priority_enc]
    urgency = URGENCY_LABEL_MAP[urgency_enc]
    impact = IMPACT_LABEL_MAP[impact_enc]

    escalation_risk = compute_escalation_risk(priority, urgency, impact)
    should_escalate = escalation_risk > settings.escalation_threshold

    result = {
        "priority": priority,
        "urgency": urgency,
        "impact": impact,
        "priority_label": PRIORITY_NAME_MAP[priority],
        "urgency_label": URGENCY_NAME_MAP[urgency],
        "impact_label": IMPACT_NAME_MAP[impact],
        "escalation_risk": escalation_risk,
        "should_escalate": should_escalate,
    }

    logger.info("Triage result: priority=%d(%s), urgency=%d(%s), impact=%d(%s), risk=%.4f%s",
                priority, result["priority_label"],
                urgency, result["urgency_label"],
                impact, result["impact_label"],
                escalation_risk, " ESCALATE" if should_escalate else "")

    return result


def unload_triage():
    global _priority_model, _urgency_model, _impact_model
    _priority_model = None
    _urgency_model = None
    _impact_model = None
    logger.info("Triage models unloaded")