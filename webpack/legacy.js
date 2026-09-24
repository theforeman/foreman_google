import $ from 'jquery';
import { translate as __ } from 'foremanReact/common/I18n';

const jsonLoader = input => {
  const file = input.files[0];
  const reader = new FileReader();
  reader.onload = () => {
    const text = reader.result;
    const outputTextField = document.getElementById('gce_json');
    outputTextField.value = text;
  };
  reader.readAsText(file);
};

const reloadSubnetworks = (networkSelect) => {
  const url = networkSelect.dataset.subnetsUrl;
  if (!url) return;

  const network = networkSelect.value;
  const form = networkSelect.closest('form');
  const subnetworkSelect = form && form.querySelector('[id$=_subnetwork]');
  if (!subnetworkSelect) return;

  const currentValue = subnetworkSelect.value;

  fetch(`${url}?network=${encodeURIComponent(network)}`, {
    headers: { 'Accept': 'application/json' },
  })
    .then(response => response.json())
    .then(subnets => {
      subnetworkSelect.innerHTML = '';

      subnets.forEach(name => {
        const option = document.createElement('option');
        option.value = name;
        option.textContent = name;
        if (name === currentValue) option.selected = true;
        subnetworkSelect.appendChild(option);
      });

      $(subnetworkSelect).trigger('change');
    });
};

const initNetworkSubnetworkBinding = () => {
  $(document).on('change', '[id$=_network][data-subnets-url]', function () {
    reloadSubnetworks(this);
  });
};

export const registerLegacy = () => {
  window.tfm = Object.assign(window.tfm || {}, {
    gce: { jsonLoader },
  });
  initNetworkSubnetworkBinding();
};
