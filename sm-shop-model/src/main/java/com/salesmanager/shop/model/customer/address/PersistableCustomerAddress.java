package com.salesmanager.shop.model.customer.address;

import java.io.Serializable;

import javax.validation.constraints.NotEmpty;
import javax.validation.constraints.NotNull;

import com.salesmanager.core.model.customer.AddressType;

import io.swagger.annotations.ApiModelProperty;

public class PersistableCustomerAddress implements Serializable {
    
    private static final long serialVersionUID = 1L;

    private Long id;

    @NotNull(message = "Address type is required")
    @ApiModelProperty(notes = "Address type: BILLING or DELIVERY", required = true)
    private AddressType addressType;

    @ApiModelProperty(notes = "Set as default address for this type")
    private boolean isDefault;

    @NotEmpty(message = "First name is required")
    @ApiModelProperty(notes = "First name", required = true)
    private String firstName;

    @NotEmpty(message = "Last name is required")
    @ApiModelProperty(notes = "Last name", required = true)
    private String lastName;

    @ApiModelProperty(notes = "Company name")
    private String company;

    @ApiModelProperty(notes = "Street address")
    private String address;

    @ApiModelProperty(notes = "City")
    private String city;

    @ApiModelProperty(notes = "Postal code")
    private String postalCode;

    @ApiModelProperty(notes = "Phone number")
    private String phone;

    @ApiModelProperty(notes = "State or province")
    private String stateProvince;

    @ApiModelProperty(notes = "Country code (e.g., US, CA, UK)")
    private String country;

    @ApiModelProperty(notes = "Zone code")
    private String zone;

    @ApiModelProperty(notes = "Latitude")
    private String latitude;

    @ApiModelProperty(notes = "Longitude")
    private String longitude;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public AddressType getAddressType() {
        return addressType;
    }

    public void setAddressType(AddressType addressType) {
        this.addressType = addressType;
    }

    public boolean isDefault() {
        return isDefault;
    }

    public void setDefault(boolean isDefault) {
        this.isDefault = isDefault;
    }

    public String getFirstName() {
        return firstName;
    }

    public void setFirstName(String firstName) {
        this.firstName = firstName;
    }

    public String getLastName() {
        return lastName;
    }

    public void setLastName(String lastName) {
        this.lastName = lastName;
    }

    public String getCompany() {
        return company;
    }

    public void setCompany(String company) {
        this.company = company;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public String getCity() {
        return city;
    }

    public void setCity(String city) {
        this.city = city;
    }

    public String getPostalCode() {
        return postalCode;
    }

    public void setPostalCode(String postalCode) {
        this.postalCode = postalCode;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public String getStateProvince() {
        return stateProvince;
    }

    public void setStateProvince(String stateProvince) {
        this.stateProvince = stateProvince;
    }

    public String getCountry() {
        return country;
    }

    public void setCountry(String country) {
        this.country = country;
    }

    public String getZone() {
        return zone;
    }

    public void setZone(String zone) {
        this.zone = zone;
    }

    public String getLatitude() {
        return latitude;
    }

    public void setLatitude(String latitude) {
        this.latitude = latitude;
    }

    public String getLongitude() {
        return longitude;
    }

    public void setLongitude(String longitude) {
        this.longitude = longitude;
    }
}
