package com.salesmanager.core.business.services.customer;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.salesmanager.core.business.exception.ServiceException;
import com.salesmanager.core.business.repositories.customer.CustomerAddressRepository;
import com.salesmanager.core.business.services.common.generic.SalesManagerEntityServiceImpl;
import com.salesmanager.core.model.customer.AddressType;
import com.salesmanager.core.model.customer.CustomerAddress;

@Service("customerAddressService")
public class CustomerAddressServiceImpl extends SalesManagerEntityServiceImpl<Long, CustomerAddress>
        implements CustomerAddressService {

    private final CustomerAddressRepository customerAddressRepository;

    @Autowired
    public CustomerAddressServiceImpl(CustomerAddressRepository customerAddressRepository) {
        super(customerAddressRepository);
        this.customerAddressRepository = customerAddressRepository;
    }

    @Override
    public List<CustomerAddress> getByCustomer(Long customerId) {
        return customerAddressRepository.findByCustomerId(customerId);
    }

    @Override
    public List<CustomerAddress> getByCustomerAndType(Long customerId, AddressType addressType) {
        return customerAddressRepository.findByCustomerIdAndAddressType(customerId, addressType);
    }

    @Override
    public CustomerAddress getDefaultAddress(Long customerId, AddressType addressType) {
        return customerAddressRepository.findDefaultByCustomerIdAndType(customerId, addressType);
    }

    @Override
    @Transactional
    public void validateAddress(CustomerAddress address, Long customerId) throws ServiceException {
        // Validate ownership
        if (address.getId() != null) {
            CustomerAddress existing = customerAddressRepository.findById(address.getId()).orElse(null);
            if (existing == null || !existing.getCustomer().getId().equals(customerId)) {
                throw new ServiceException("Address does not belong to customer");
            }
        }

        // Validate no identical billing and delivery addresses
        AddressType oppositeType = address.getAddressType() == AddressType.BILLING 
            ? AddressType.DELIVERY : AddressType.BILLING;
        
        List<CustomerAddress> oppositeAddresses = getByCustomerAndType(customerId, oppositeType);
        
        for (CustomerAddress existing : oppositeAddresses) {
            if (areAddressesIdentical(address, existing)) {
                throw new ServiceException("Billing and delivery addresses cannot be identical");
            }
        }
    }

    private boolean areAddressesIdentical(CustomerAddress addr1, CustomerAddress addr2) {
        return normalize(addr1.getAddress()).equals(normalize(addr2.getAddress()))
            && normalize(addr1.getCity()).equals(normalize(addr2.getCity()))
            && normalize(addr1.getPostalCode()).equals(normalize(addr2.getPostalCode()))
            && (addr1.getCountry() != null && addr2.getCountry() != null 
                && addr1.getCountry().getId().equals(addr2.getCountry().getId()));
    }

    private String normalize(String value) {
        return value == null ? "" : value.trim().toLowerCase();
    }
}
