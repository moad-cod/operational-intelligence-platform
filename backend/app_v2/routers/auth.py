import logging

from fastapi import APIRouter, Depends

from app_v2.core.dependencies import get_auth_service, get_current_user
from app_v2.models.auth import (
    LoginRequest,
    RefreshRequest,
    TokenResponse,
)
from app_v2.models.user import User
from app_v2.services.auth_service import AuthService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=TokenResponse)
async def login(
    request: LoginRequest,
    auth_service: AuthService = Depends(get_auth_service),
):
    result = await auth_service.login(
        username=request.username,
        plain_password=request.password,
    )
    return TokenResponse(**result)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(
    request: RefreshRequest,
    auth_service: AuthService = Depends(get_auth_service),
):
    result = await auth_service.refresh(
        refresh_token=request.refresh_token,
    )
    return TokenResponse(**result)


@router.post("/logout")
async def logout(
    current_user: User = Depends(get_current_user),
):
    return {"message": "Logged out successfully"}
