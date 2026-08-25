from datetime import datetime

from pydantic import BaseModel, ConfigDict


class SiteBase(BaseModel):
    name: str
    location: str
    country: str
    status: str = "active"


class SiteCreate(SiteBase):
    pass


class SiteResponse(SiteBase):
    id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)