package com.salesmanager.shop.store.facade.customer;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.salesmanager.core.business.exception.ServiceException;
import com.salesmanager.core.business.services.customer.CustomerAddressService;
import com.salesmanager.core.business.services.customer.CustomerService;
import com.salesmanager.core.business.services.reference.country.CountryService;
import com.salesmanager.core.business.services.reference.zone.ZoneService;
import com.salesmanager.core.model.customer.Customer;
import com.salesmanager.core.model.customer.CustomerAddress;
import com.salesmanager.core.model.merchant.MerchantStore;
import com.salesmanager.core.model.reference.country.Country;
import com.salesmanager.core.model.reference.zone.Zone;
import com.salesmanager.shop.model.customer.address.PersistableCustomerAddress;
import com.salesmanager.shop.model.customer.address.ReadableCustomerAddress;
import com.salesmanager.shop.store.api.exception.ResourceNotFoundException;
import com.salesmanager.shop.store.api.exception.ServiceRuntimeException;

@Service("customerAddressFacade")
public class CustomerAddressFacadeImpl implements CustomerAddressFacade {

    @Autowired
    private CustomerAddressService customerAddressService;

    @Autowired
    private CustomerService customerService;

    @Autowired
    private CountryService countryService;

    @Autowired
    private ZoneService zoneService;

    @Override
    @Transactional
    public ReadableCustomerAddress create(PersistableCustomerAddress address, Long customerId, MerchantStore store) {
        try {
            Customer customer = customerService.getById(customerId);
            if (customer == null) {
                throw new ResourceNotFoundException("Customer not found");
            }

            CustomerAddress entity = toEntity(address, customer, store);
            customerAddressService.validateAddress(entity, customerId);
            customerAddressService.save(entity);

            return toReadable(entity);
        } catch (ServiceException e) {
            throw new ServiceRuntimeException(e);
        }
    }

    @Override
    @Transactional
    public ReadableCustomerAddress update(Long addressId, PersistableCustomerAddress address, Long customerId, MerchantStore store) {
        try {
            CustomerAddress existing = customerAddressService.getById(addressId);
            if (existing == null || !existing.getCustomer().getId().equals(customerId)) {
                throw new ResourceNotFoundException("Address not found");
            }

            Customer customer = existing.getCustomer();
            CustomerAddress updated = toEntity(address, customer, store);
            updated.setId(addressId);
            
            customerAddressService.validateAddress(updated, customerId);
            customerAddressService.update(updated);

            return toReadable(updated);
        } catch (ServiceException e) {
            throw new ServiceRuntimeException(e);
        }
    }

    @Override
    @Transactional
    public void delete(Long addressId, Long customerId) {
        CustomerAddress existing = customerAddressService.getById(addressId);
        if (existing == null || !existing.getCustomer().getId().equals(customerId)) {
            throw new ResourceNotFoundException("Address not found");
        }
        try {
            customerAddressService.delete(existing);
        } catch (ServiceException e) {
            throw new ServiceRuntimeException(e);
        }
    }

    @Override
    public ReadableCustomerAddress getById(Long addressId, Long customerId) {
        CustomerAddress address = customerAddressService.getById(addressId);
        if (address == null || !address.getCustomer().getId().equals(customerId)) {
            throw new ResourceNotFoundException("Address not found");
        }
        return toReadable(address);
    }

    @Override
    public List<ReadableCustomerAddress> getByCustomer(Long customerId) {
        List<CustomerAddress> addresses = customerAddressService.getByCustomer(customerId);
        return addresses.stream().map(this::toReadable).collect(Collectors.toList());
    }

    private CustomerAddress toEntity(PersistableCustomerAddress dto, Customer customer, MerchantStore store) {
        CustomerAddress entity = new CustomerAddress();
        entity.setCustomer(customer);
        entity.setAddressType(dto.getAddressType());
        entity.setDefault(dto.isDefault());
        entity.setFirstName(dto.getFirstName());
        entity.setLastName(dto.getLastName());
        entity.setCompany(dto.getCompany());
        entity.setAddress(dto.getAddress());
        entity.setCity(dto.getCity());
        entity.setPostalCode(dto.getPostalCode());
        entity.setPhone(dto.getPhone());
        entity.setStateProvince(dto.getStateProvince());
        entity.setLatitude(dto.getLatitude());
        entity.setLongitude(dto.getLongitude());

        if (dto.getCountry() != null) {
            try {
                Country country = countryService.getByCode(dto.getCountry());
                entity.setCountry(country);
            } catch (ServiceException e) {
                // Country not found, skip
            }
        }

        if (dto.getZone() != null) {
            Zone zone = zoneService.getByCode(dto.getZone());
            entity.setZone(zone);
        }

        return entity;
    }

    private ReadableCustomerAddress toReadable(CustomerAddress entity) {
        ReadableCustomerAddress dto = new ReadableCustomerAddress();
        dto.setId(entity.getId());
        dto.setAddressType(entity.getAddressType());
        dto.setDefault(entity.isDefault());
        dto.setFirstName(entity.getFirstName());
        dto.setLastName(entity.getLastName());
        dto.setCompany(entity.getCompany());
        dto.setAddress(entity.getAddress());
        dto.setCity(entity.getCity());
        dto.setPostalCode(entity.getPostalCode());
        dto.setPhone(entity.getPhone());
        dto.setStateProvince(entity.getStateProvince());
        dto.setLatitude(entity.getLatitude());
        dto.setLongitude(entity.getLongitude());

        if (entity.getCountry() != null) {
            dto.setCountry(entity.getCountry().getIsoCode());
        }

        if (entity.getZone() != null) {
            dto.setZone(entity.getZone().getCode());
        }

        return dto;
    }
}
