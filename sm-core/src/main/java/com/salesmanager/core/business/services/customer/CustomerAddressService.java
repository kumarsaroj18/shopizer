package com.salesmanager.core.business.services.customer;

import java.util.List;

import com.salesmanager.core.business.exception.ServiceException;
import com.salesmanager.core.business.services.common.generic.SalesManagerEntityService;
import com.salesmanager.core.model.customer.AddressType;
import com.salesmanager.core.model.customer.CustomerAddress;

public interface CustomerAddressService extends SalesManagerEntityService<Long, CustomerAddress> {
    
    List<CustomerAddress> getByCustomer(Long customerId);
    
    List<CustomerAddress> getByCustomerAndType(Long customerId, AddressType addressType);
    
    CustomerAddress getDefaultAddress(Long customerId, AddressType addressType);
    
    void validateAddress(CustomerAddress address, Long customerId) throws ServiceException;
}
