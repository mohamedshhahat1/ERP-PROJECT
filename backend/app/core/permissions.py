from enum import Enum


class Role(str, Enum):
    ADMIN = "admin"
    MANAGER = "manager"
    CASHIER = "cashier"
    ACCOUNTANT = "accountant"
    WAREHOUSE_EMPLOYEE = "warehouse_employee"


ROLE_PERMISSIONS = {
    Role.ADMIN: [
        "dashboard:read",
        "products:read", "products:write", "products:delete",
        "categories:read", "categories:write", "categories:delete",
        "inventory:read", "inventory:write", "inventory:transfer",
        "sales:read", "sales:write", "sales:return",
        "purchases:read", "purchases:write", "purchases:return",
        "customers:read", "customers:write", "customers:delete",
        "suppliers:read", "suppliers:write", "suppliers:delete",
        "payments:read", "payments:write",
        "expenses:read", "expenses:write",
        "accounting:read", "accounting:write",
        "reports:read", "reports:export",
        "users:read", "users:write", "users:delete",
        "notifications:read", "notifications:write",
        "settings:read", "settings:write",
    ],
    Role.MANAGER: [
        "dashboard:read",
        "products:read", "products:write",
        "categories:read", "categories:write",
        "inventory:read", "inventory:write", "inventory:transfer",
        "sales:read", "sales:write", "sales:return",
        "purchases:read", "purchases:write", "purchases:return",
        "customers:read", "customers:write",
        "suppliers:read", "suppliers:write",
        "payments:read", "payments:write",
        "expenses:read", "expenses:write",
        "accounting:read",
        "reports:read", "reports:export",
        "notifications:read", "notifications:write",
    ],
    Role.CASHIER: [
        "dashboard:read",
        "products:read",
        "categories:read",
        "inventory:read",
        "sales:read", "sales:write", "sales:return",
        "customers:read", "customers:write",
        "payments:read", "payments:write",
        "expenses:read", "expenses:write",
        "notifications:read",
    ],
    Role.ACCOUNTANT: [
        "dashboard:read",
        "products:read",
        "categories:read",
        "inventory:read",
        "sales:read",
        "purchases:read",
        "customers:read",
        "suppliers:read",
        "payments:read", "payments:write",
        "expenses:read", "expenses:write",
        "accounting:read", "accounting:write",
        "reports:read", "reports:export",
        "notifications:read",
    ],
    Role.WAREHOUSE_EMPLOYEE: [
        "dashboard:read",
        "products:read",
        "categories:read",
        "inventory:read", "inventory:write", "inventory:transfer",
        "purchases:read",
        "notifications:read",
    ],
}


def has_permission(role: str, permission: str) -> bool:
    try:
        role_enum = Role(role)
    except ValueError:
        return False
    return permission in ROLE_PERMISSIONS.get(role_enum, [])
