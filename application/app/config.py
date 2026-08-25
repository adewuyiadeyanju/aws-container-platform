from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "FieldOps API"
    app_version: str = "1.0.0"
    environment: str = "development"

    database_host: str
    database_port: int = 5432
    database_name: str = "fieldops"
    database_username: str
    database_password: str

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


settings = Settings()