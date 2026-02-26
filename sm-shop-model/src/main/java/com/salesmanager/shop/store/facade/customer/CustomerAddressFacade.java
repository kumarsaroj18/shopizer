package com.salesmanager.shop.store.facade.customer;

import java.util.List;

import com.salesmanager.core.model.merchant.MerchantStore;
import com.salesmanager.shop.model.customer.address.PersistableCustomerAddress;
import com.salesmanager.shop.model.customer.address.ReadableCustomerAddress;

public interface CustomerAddressFacade {
    
    ReadableCustomerAddress create(PersistableCustomerAddress address, Long customerId, MerchantStore store);
    
    ReadableCustomerAddress update(Long addressId, PersistableCustomerAddress address, Long customerId, MerchantStore store);
    
    void delete(Long addressId, Long customerId);
    
    ReadableCustomerAddress getById(Long addressId, Long customerId);
    
    List<ReadableCustomerAddress> getByCustomer(Long customerId);
}
