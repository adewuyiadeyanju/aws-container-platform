from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Site
from app.schemas import SiteCreate, SiteResponse


router = APIRouter(
    prefix="/api/v1/sites",
    tags=["sites"],
)


@router.post(
    "",
    response_model=SiteResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_site(
    site: SiteCreate,
    db: Session = Depends(get_db),
):
    new_site = Site(**site.model_dump())

    db.add(new_site)
    db.commit()
    db.refresh(new_site)

    return new_site


@router.get(
    "",
    response_model=list[SiteResponse],
)
def list_sites(
    db: Session = Depends(get_db),
):
    result = db.execute(
        select(Site).order_by(Site.id)
    )

    return result.scalars().all()


@router.get(
    "/{site_id}",
    response_model=SiteResponse,
)
def get_site(
    site_id: int,
    db: Session = Depends(get_db),
):
    site = db.get(Site, site_id)

    if site is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Site not found",
        )

    return site


@router.put(
    "/{site_id}",
    response_model=SiteResponse,
)
def update_site(
    site_id: int,
    site_data: SiteCreate,
    db: Session = Depends(get_db),
):
    site = db.get(Site, site_id)

    if site is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Site not found",
        )

    for field, value in site_data.model_dump().items():
        setattr(site, field, value)

    db.commit()
    db.refresh(site)

    return site


@router.delete(
    "/{site_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_site(
    site_id: int,
    db: Session = Depends(get_db),
):
    site = db.get(Site, site_id)

    if site is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Site not found",
        )

    db.delete(site)
    db.commit()