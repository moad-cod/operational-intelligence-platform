import logging

from fastapi import APIRouter, Depends, status

from app_v2.core.dependencies import get_auth_service
from app_v2.models.auth import RegisterRequest, RegisterResponse
from app_v2.services.auth_service import AuthService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/register", tags=["Registration"])


@router.post(
    "",
    response_model=RegisterResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    request: RegisterRequest,
    auth_service: AuthService = Depends(get_auth_service),
):
    result = await auth_service.register(
        username=request.username,
        email=request.email,
        plain_password=request.password,
        role=request.role,
    )
    return RegisterResponse(**result)
