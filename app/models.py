
from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.database import Base


class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    image = Column(String(500), nullable=True)
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    products = relationship("Product", back_populates="category")


class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=False)

    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Integer, default=0)
    image = Column(String(500), nullable=True)

    is_active = Column(Boolean, default=True)
    is_orderable = Column(Boolean, default=False)
    order_fields = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

    category = relationship("Category", back_populates="products")
    orders = relationship("Order", back_populates="product")


class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)

    customer_name = Column(String(255), nullable=True)
    customer_phone = Column(String(100), nullable=True)
    quantity = Column(Integer, default=1)

    answers_json = Column(Text, nullable=True)
    status = Column(String(100), default="new")
    telegram_message_id = Column(String(100), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)

    product = relationship("Product", back_populates="orders")


class AgentOrder(Base):
    __tablename__ = "agent_orders"

    id = Column(Integer, primary_key=True, index=True)
    store_name = Column(String(255), nullable=False)
    status = Column(String(100), default="new")
    total_amount = Column(Integer, default=0)
    telegram_message_id = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    items = relationship("AgentOrderItem", back_populates="order")


class AgentOrderItem(Base):
    __tablename__ = "agent_order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("agent_orders.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)

    product_name = Column(String(255), nullable=False)
    price = Column(Integer, default=0)
    quantity = Column(Integer, default=1)
    line_total = Column(Integer, default=0)

    order = relationship("AgentOrder", back_populates="items")
    product = relationship("Product")
