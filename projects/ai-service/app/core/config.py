from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """All values are configuration-driven and overridable per environment."""

    model_config = SettingsConfigDict(env_prefix="AI_")

    app_name: str = "quote-assist-ai"
    default_model: str = "claude-haiku"
    max_concurrent_ai_calls: int = 5
    embedding_model: str = "text-embedding-3-small"
    rag_min_corrections: int = 10
    rag_similarity_threshold: float = 0.75


settings = Settings()
