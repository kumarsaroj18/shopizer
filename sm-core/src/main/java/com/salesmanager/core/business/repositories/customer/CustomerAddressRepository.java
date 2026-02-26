package com.salesmanager.core.business.repositories.customer;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.salesmanager.core.model.customer.AddressType;
import com.salesmanager.core.model.customer.CustomerAddress;

public interface CustomerAddressRepository extends JpaRepository<CustomerAddress, Long> {
    
    List<CustomerAddress> findByCustomerId(Long customerId);
    
    List<CustomerAddress> findByCustomerIdAndAddressType(Long customerId, AddressType addressType);
    
    @Query("SELECT ca FROM CustomerAddress ca WHERE ca.customer.id = ?1 AND ca.addressType = ?2 AND ca.isDefault = true")
    CustomerAddress findDefaultByCustomerIdAndType(Long customerId, AddressType addressType);
}
